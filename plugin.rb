# name: paved-email-banner
# version: 0.1.1
# author: Muhlis Budi Cahyono (muhlisbc@gmail.com)

enabled_site_setting :paved_email_banner_enabled

after_initialize {

  class ::PavedEmailBanner

    def initialize(message)
      @message = message
      @random_id = SecureRandom.alphanumeric
    end

    def html
      banner = %w(desktop mobile).map do |size|
        banner_class = "banner" + size.capitalize

        <<~HTML
          <div class="pavedBanner #{banner_class}">
            <a href="#{banner_url}" class="pavedBanner #{banner_class}" title="">
              <span class="#{banner_class}">
                <img class="pavedBannerImg #{banner_class}" src="#{banner_img(size)}" alt="banner" width="" height="" />
              </span>
            </a>
          </div>
        HTML
      end.join

      style + banner
    end

    private

      def style
        <<~HTML
          <style>

            .pavedBanner {
              display: block;
              width: 100% !important;
            }

            .pavedBannerImg {
              width: 100% !important;
              height: auto !important;
            }

            @media only screen and (max-device-width:480px) {
              .bannerDesktop {
                display: none !important;
              }
            }

            @media only screen and (min-device-width:481px) {
              .bannerMobile {
                display: none !important;
              }
            }

          </style>
        HTML
      end

      def banner_url
        "#{SiteSetting.paved_email_banner_base_url}/click?id=#{@random_id}"
      end

      def banner_img(size)
        params = { size: size, id: @random_id }

        if SiteSetting.paved_email_banner_include_email
          params[:email] = @message.to
        end

        "#{SiteSetting.paved_email_banner_base_url}/banner/#{SiteSetting.paved_email_banner_api_key}?#{params.to_query}"
      end

  end

  require_dependency "email/renderer"
  Email::Renderer.class_eval {

    alias_method :orig_html, :html

    def html
      html_str = orig_html

      return html_str if !SiteSetting.paved_email_banner_enabled

      banner = PavedEmailBanner.new(@message).html

      if (SiteSetting.paved_email_banner_selective_placement && @message.discourse_email_type != "digest")
        html_str.gsub!("[paved_email_banner]", banner)

        return html_str
      else
        html_str.gsub!("[paved_email_banner]", "")
        fragment  = Nokogiri::HTML.fragment(html_str)
        body_el   = fragment.css("body").first

        if body_el
          body_el.prepend_child(banner)
        else
          fragment.prepend_child(banner)
        end

        return fragment.to_html
      end
    end

  }

  require_dependency "user_notifications"
  UserNotifications.class_eval {
    alias_method :orig_digest, :digest

    def digest(user, opts = {})
      message = orig_digest(user, opts)

      return message if !SiteSetting.paved_email_banner_enabled

      if message
        message.discourse_email_type = "digest"
      end

      message
    end
  }

  ::Mail::Message.class_eval {
    attr_accessor :discourse_email_type
  }

}
