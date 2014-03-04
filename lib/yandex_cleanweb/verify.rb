require "uri"
require "nokogiri"
require "net/http"

module YandexCleanweb
  module Verify
    class << self

      def spam?(*options)
        response = api_check_spam(options)
        doc = Nokogiri::XML(response)

        request_id_tag = doc.xpath('//check-spam-result/id')
        spam_flag_tag = doc.xpath('//check-spam-result/text')

        raise BadResponseException if request_id_tag.size.zero?

        request_id = request_id_tag[0].content
        spam_flag = spam_flag_tag[0].attributes["spam-flag"].content

        if spam_flag == 'yes'
          links = doc.xpath('//check-spam-result/links')[0].children

          links.map do |el|
            [el.attributes["url"], el.attributes["spam_flag"] == 'yes']
          end

          { id: request_id, links: links }
        else
          false
        end
      end

      def get_captcha(request_id=nil)
        response = api_get_captcha(request_id)
        doc = Nokogiri::XML(response)

        url = doc.xpath('//get-captcha-result/url').text
        captcha_id = doc.xpath('//get-captcha-result/captcha').text

        { url: url, captcha: captcha_id }
      end

      def valid_captcha?(request_id=nil)
        value = params[:captcha_response_field]
        captcha_id = params[:captcha_response_id]
        response = api_check_captcha(request_id, captcha_id, value)
        doc = Nokogiri::XML(response)
        doc.xpath('//check-captcha-result/ok').any?
      end

      private

      def api_check_captcha(request_id, captcha_id, value)
        check_captcha_url = "#{API_URL}/check-captcha"
        params = {
            key: prepare_api_key,
            id: request_id,
            captcha: captcha_id,
            value: value
        }

        uri = URI.parse(check_captcha_url)
        uri.query = URI.encode_www_form(params)

        Net::HTTP.get(uri)
      end

      def api_get_captcha(request_id)
        get_captcha_url = "#{API_URL}/get-captcha"
        params = { key: prepare_api_key, id: request_id, type: YandexCleanweb.configuration.captcha_type }

        uri = URI.parse(get_captcha_url)
        uri.query = URI.encode_www_form(params)

        Net::HTTP.get(uri)
      end

      def api_check_spam(options)
        cleanweb_options = { key: prepare_api_key }

        if options[0].is_a?(String) # quick check
          cleanweb_options[:body_plain] = options[0]
        else
          options = options[0]
          cleanweb_options.merge!(Hash[options.map{ |k,v| [k.to_s.gsub("_","-"), v] }])
        end

        check_spam_url = "#{API_URL}/check-spam"
        uri = URI.parse(check_spam_url)
        response = Net::HTTP.post_form(uri, cleanweb_options)
        response.body
      end

      def prepare_api_key
        raise NoApiKeyException if YandexCleanweb.configuration.api_key.nil? || YandexCleanweb.configuration.api_key.empty?

        YandexCleanweb.configuration.api_key
      end
    end
  end
end
