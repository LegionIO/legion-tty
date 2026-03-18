# frozen_string_literal: true

require 'resolv'
require 'shellwords'

module Legion
  module TTY
    module Background
      # rubocop:disable Metrics/ClassLength
      class KerberosProbe
        def initialize(logger: nil)
          @log = logger
        end

        def probe
          principal = read_principal
          return nil unless principal

          username = principal.split('@', 2).first
          realm = principal.include?('@') ? principal.split('@', 2).last : nil
          profile = ldap_profile(username, realm)

          build_result(principal: principal, username: username, realm: realm, profile: profile)
        end

        def run_async(queue)
          Thread.new do
            @log&.log('kerberos', 'running klist...')
            t0 = Time.now
            result = probe
            elapsed = ((Time.now - t0) * 1000).round
            log_result(result, elapsed)
            queue.push(type: :kerberos_complete, data: result)
          rescue StandardError => e
            @log&.log('kerberos', "ERROR: #{e.class}: #{e.message}")
            queue.push(type: :kerberos_error, error: e.message)
          end
        end

        private

        def read_principal
          output = `klist 2>/dev/null`
          return nil unless $CHILD_STATUS&.success?

          match = output.match(/Principal:\s+(\S+)/i)
          match&.[](1)&.strip
        end

        def ldap_profile(username, realm)
          @log&.log('kerberos', "ldap_profile called: username=#{username} realm=#{realm.inspect}")
          return {} unless realm

          dc_host = discover_dc(realm)
          unless dc_host
            @log&.log('kerberos', "no domain controller found for #{realm}")
            return {}
          end

          base_dn = realm_to_base_dn(realm)
          @log&.log('kerberos', "LDAP lookup: #{username} via #{dc_host} base=#{base_dn}")
          query_ldap(username: username, host: dc_host, base_dn: base_dn)
        end

        # rubocop:disable Metrics/CyclomaticComplexity
        def discover_dc(realm)
          domain = realm.downcase
          srv_name = "_ldap._tcp.#{domain}"
          records = Resolv::DNS.open { |dns| dns.getresources(srv_name, Resolv::DNS::Resource::IN::SRV) }
          host = records.min_by(&:priority)&.target&.to_s
          @log&.log('kerberos', "SRV #{srv_name} -> #{host || 'none'} (#{records.size} records)")
          host
        rescue StandardError => e
          @log&.log('kerberos', "SRV lookup failed: #{e.message}")
          nil
        end
        # rubocop:enable Metrics/CyclomaticComplexity

        def realm_to_base_dn(realm)
          realm.downcase.split('.').map { |part| "DC=#{part}" }.join(',')
        end

        def query_ldap(username:, host:, base_dn:)
          output = run_ldapsearch(username: username, host: host, base_dn: base_dn)
          return {} unless output

          profile = parse_ldif(output)
          @log&.log('kerberos', "LDAP profile: #{profile.inspect}")
          profile
        rescue StandardError => e
          @log&.log('kerberos', "LDAP error: #{e.class}: #{e.message}")
          {}
        end

        def run_ldapsearch(username:, host:, base_dn:)
          cmd = "ldapsearch -H ldap://#{host} -b #{base_dn.shellescape} " \
                "\"(sAMAccountName=#{username.shellescape})\" " \
                'givenName sn mail displayName title department company ' \
                'l st co whenCreated 2>/dev/null'
          output = `#{cmd}`
          return nil unless $CHILD_STATUS&.success?

          output
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        def parse_ldif(output)
          attrs = {}
          output.each_line do |line|
            line = line.chomp
            case line
            when /\AgivenName:\s*(.+)/   then attrs[:first_name] = Regexp.last_match(1).strip
            when /\Asn:\s*(.+)/          then attrs[:last_name] = Regexp.last_match(1).strip
            when /\Amail:\s*(.+)/        then attrs[:email] = Regexp.last_match(1).strip
            when /\AdisplayName:\s*(.+)/ then attrs[:display_name] = Regexp.last_match(1).strip
            when /\Atitle:\s*(.+)/       then attrs[:title] = Regexp.last_match(1).strip
            when /\Adepartment:\s*(.+)/  then attrs[:department] = Regexp.last_match(1).strip
            when /\Acompany:\s*(.+)/     then attrs[:company] = Regexp.last_match(1).strip
            when /\Al:\s*(.+)/           then attrs[:city] = Regexp.last_match(1).strip
            when /\Ast:\s*(.+)/          then attrs[:state] = Regexp.last_match(1).strip
            when /\Aco:\s*(.+)/          then attrs[:country] = Regexp.last_match(1).strip
            when /\AwhenCreated:\s*(.+)/ then attrs[:when_created] = Regexp.last_match(1).strip
            end
          end
          attrs
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

        def build_result(principal:, username:, realm:, profile:)
          first = profile[:first_name] || username.capitalize
          last = profile[:last_name]
          display = profile[:display_name] || [first, last].compact.join(' ')

          {
            principal: principal,
            username: username,
            realm: realm,
            first_name: first,
            last_name: last,
            email: profile[:email],
            display_name: display,
            title: profile[:title],
            department: profile[:department],
            company: profile[:company],
            city: profile[:city],
            state: profile[:state],
            country: profile[:country],
            tenure_years: calculate_tenure(profile[:when_created])
          }.compact
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        def calculate_tenure(when_created)
          return nil unless when_created&.length&.>=(8)

          # AD generalized time: 20170505044456.0Z
          start_year = when_created[0, 4].to_i
          start_month = when_created[4, 2].to_i
          start_day = when_created[6, 2].to_i
          return nil if start_year.zero?

          now = Time.now
          days = now.day - start_day
          months = now.month - start_month
          years = now.year - start_year

          if days.negative?
            months -= 1
            prev_month = now.month - 1
            prev_year = now.year
            if prev_month.zero?
              prev_month = 12
              prev_year -= 1
            end
            days += days_in_month(prev_month, prev_year)
          end

          if months.negative?
            years -= 1
            months += 12
          end

          return nil if years.negative?

          { years: years, months: months, days: days }
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

        def days_in_month(month, year)
          Time.new(year, month, -1).day
        end

        def log_result(result, elapsed)
          if result
            @log&.log('kerberos', "found principal: #{result[:principal]} (#{elapsed}ms)")
            @log&.log('kerberos', "name=#{result[:display_name]} email=#{result[:email]}")
          else
            @log&.log('kerberos', "no kerberos ticket found (#{elapsed}ms)")
          end
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
