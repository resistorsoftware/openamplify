require 'net/http'
require 'uri'
require 'json'

module OpenAmplify
  API_URL = "http://portaltnx20.openamplify.com/AmplifyWeb_v20/AmplifyThis"

  class Client
    def initialize(options={})
      @options = { :base_url => API_URL, :method => :get }
      @options.merge!(OpenAmplify.symbolize_keys(options))
    end

    def analyze_text(text)
      Response.new(:base_url => @options[:base_url], :query => query.merge(:inputText => text), 
                   :method => @options[:method])
    end
    
    %w(api_key analysis base_url method).each do |attr|
      class_eval <<-EOS
        def #{attr}
          @options[:#{attr}]
        end

        def #{attr}=(v)
          @options[:#{attr}] = v 
        end
      EOS
    end

    private

    def query
      q = { :apiKey => @options[:api_key] }
      q.merge!(:analysis => @options[:analysis]) if @options[:analysis]
      q
    end

  end # OpenAmplify::Client 

  # Contains the response from OpenAmplify
  class Response
    include Enumerable

    def initialize(options)
      @options = options
    end

    def request_url
      @request_url ||= compose_url(@options[:base_url], @options[:query]) 
    end
    
    def each
      response.each do |k, v|
        yield(k, v)
      end
    end

    def method_missing(name, *args, &block)
      response.send(name, *args, &block)
    end
     
    # Support the different formats. Note this would entail another request
    # to openamplify
    %w(xml json rdf csv oas signals pretty).each do |format|
      class_eval <<-EOS
        def to_#{format}
          fetch_as_format(:#{format})
        end
      EOS
    end

    def top_topics
      items = response && response['Topics']['TopTopics']
    end

    def proper_nouns
      items = response && response['Topics']['ProperNouns']

      return items if items.is_a?(Array)

      # I'm not sure if this is the default behavior if
      # only a single item is found, or if it is a bug
      # TODO: check other helpers as well
      if items.is_a?(Hash)
        return [ items['TopicResult'] ]
      end
    end

    def locations
      response && response['Topics']['Locations']
    end

    def domains
      response && response['Topics']['Domains']
    end

    private
    def compose_url(path, params)
      path + '?' + URI.escape(params.collect{ |k, v| "#{k}=#{v}" }.join('&'))
    end

    def response
      @response ||= fetch_response
    end
  
    def fetch_response
      response = fetch_as_format(:json)
      result   = JSON.parse(response)

      if analysis = @options[:query][:analysis]
        name = analysis.sub(/./){ |s| s.upcase }
        result["ns1:#{name}Response"]["#{name}Return"]
      else
        result['ns1:AmplifyResponse']['AmplifyReturn']
      end
    end

    def fetch_as_format(format)
      fetch(@options[:base_url], @options[:query].merge(:outputFormat => format), @options[:method])
    end

    def fetch(path, params, method)
      self.send(method, path, params)
    end

    def get(path, params)
      url = compose_url(path, params)
      Net::HTTP.get_response(URI.parse(url)).body
    end

    def post(path, params)
      uri = URI::parse(path)
      Net::HTTP.post_form(uri, params).body
    end

  end # OpenAmplify::Response

  private 

  def self.symbolize_keys(hash)
    hash.inject({}) do |options, (key, value)|
      options[(key.to_sym rescue key) || key] = value
      options
    end
  end

end # module OpenAmplify
