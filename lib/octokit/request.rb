require 'multi_json'

module Octokit
  module Request
    def delete(path, options={}, version=api_version, authenticate=true, raw=false, force_urlencoded=false)
      request(:delete, path, options, version, authenticate, raw, force_urlencoded)
    end

    def get(path, options={}, version=api_version, authenticate=true, raw=false, force_urlencoded=false)
      request(:get, path, options, version, authenticate, raw, force_urlencoded)
    end

    def patch(path, options={}, version=api_version, authenticate=true, raw=false, force_urlencoded=false)
      request(:patch, path, options, version, authenticate, raw, force_urlencoded)
    end

    def post(path, options={}, version=api_version, authenticate=true, raw=false, force_urlencoded=false)
      request(:post, path, options, version, authenticate, raw, force_urlencoded)
    end

    def put(path, options={}, version=api_version, authenticate=true, raw=false, force_urlencoded=false)
      request(:put, path, options, version, authenticate, raw, force_urlencoded)
    end

    def ratelimit
      headers = get("rate_limit",{}, api_version, true, true).headers
      return headers["X-RateLimit-Limit"].to_i
    end
    alias rate_limit ratelimit

    def ratelimit_remaining
      headers = get("rate_limit",{}, api_version, true, true).headers
      return headers["X-RateLimit-Remaining"].to_i
    end
    alias rate_limit_remaining ratelimit_remaining

    private

    def request(method, path, options, version, authenticate, raw, force_urlencoded)
      path.sub(%r{^/}, '') #leading slash in path fails in github:enterprise

      octokit_options = {
        :authenticate => authenticate,
        :raw => raw,
        :version => version,
        :force_urlencoded => force_urlencoded,
        :media_type => {
          :version => nil,
          :param => nil,
          :format => 'json'
        }
      }

      if options.is_a?(Hash) && !options[:octokit].nil?
        valid_octokit_keys = [:media_type, :raw, :authenticate]
        options[:octokit].reject! { |key, _| !valid_octokit_keys.include?(key) }
        octokit_options.merge! options.delete(:octokit)
      end

      response = connection(octokit_options).send(method) do |request|
        case method
        when :delete, :get
          if auto_traversal && per_page.nil?
            self.per_page = 100
          end
          options.merge!(:per_page => per_page) if per_page
          request.url(path, options)
        when :patch, :post, :put
          request.path = path
          if 3 == version && !force_urlencoded
            request.body = MultiJson.dump(options) unless options.empty?
          else
            request.body = options unless options.empty?
          end
        end

        if Octokit.request_host
          request.headers['Host'] = Octokit.request_host
        end

        request.headers['Accept'] = media_type_header(octokit_options[:media_type])
      end

      if raw
        response
      elsif auto_traversal && ( next_url = links(response)["next"] )
        response.body + request(method, next_url, options, version, authenticate, raw, force_urlencoded)
      else
        response.body
      end
    end

    def links(response)
      links = ( response.headers["Link"] || "" ).split(', ').map do |link|
        url, type = link.match(/<(.*?)>; rel="(\w+)"/).captures
        [ type, url ]
      end

      Hash[ *links.flatten ]
    end

    def media_type_header(options={})
      media_type = 'application/vnd.github'

      case options[:version]
      when String
        media_type << '.' << options[:version]
      when Integer
        media_type << '.v' << options[:version].to_s
      end

      if options[:param]
        media_type << '.' << options[:param]
      end

      if options[:format]
        media_type << '+' << options[:format]
      end

      media_type
    end
  end
end
