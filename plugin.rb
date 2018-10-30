# name: paved-email-banner	
# version: 0.1.4	
# author: Paved (hey@paved.com	

enabled_site_setting :paved_email_banner_enabled

after_initialize {

  SiteSetting.strip_images_from_short_emails = false

  class ::PavedEmailBanner

    def initialize(message)
      @message = message
      @random_id = SecureRandom.alphanumeric
    end

    def banner
      %w(desktop).map do |size|
        banner_class = "banner" + size.capitalize

        <<~HTML
          <div class="pavedBanner #{banner_class}">
            <a href="#{banner_url}" class="pavedBanner #{banner_class}" title="">
              <span class="#{banner_class}">
                <img class="pavedBannerImg #{banner_class}" src="#{banner_img(size)}" alt="banner" width="" height="" style="max-width:420px" />
              </span>
            </a>
          </div>
        HTML
      end.join
    end

    def html
      style + banner
    end

    def style
      <<~HTML
        <style type="text/css">
          .pavedBanner {
            display: block;
            width: 100% !important;
            text-align: center;
          }

          .pavedBannerImg {
            width: 100% !important;
            height: auto !important;
          }

          @media only screen and (max-device-width:480px) {
            .bannerDesktop {
              display: none !important;
              max-width: 315px !important;
              max-height: 98px !important;
            }
          }

          @media only screen and (min-device-width:481px) {
            .bannerMobile {
              display: none !important;
              max-width: 420px !important;
              max-height: 130px !important;
            }
          }
        </style>
      HTML
    end

    private

      def banner_url
        "https://serve.paved.com/click?id=#{@random_id}"
      end

      def banner_img(size)
        params = { size: size, id: @random_id }

        if SiteSetting.paved_email_banner_include_email
          params[:email] = @message.to
        end

        "https://serve.paved.com/banner/#{SiteSetting.paved_email_banner_api_key}?#{params.to_query}"
      end

  end

  require_dependency "email/renderer"
  Email::Renderer.class_eval {

    alias_method :orig_html, :html

    def html
      html_str = orig_html

      if !SiteSetting.paved_email_banner_enabled
        return html_str.gsub("[paved_email_banner]", "")
      end

      paved_email_banner = PavedEmailBanner.new(@message)
      banner = paved_email_banner.banner
      fragment = nil

      if (SiteSetting.paved_email_banner_selective_placement && @message.discourse_email_type != "digest")
        html_str.gsub!("[paved_email_banner]", banner)
        fragment = Nokogiri::HTML.fragment(html_str)
      else
        html_str.gsub!("[paved_email_banner]", "")

        fragment  = Nokogiri::HTML.fragment(html_str)
        body_el   = fragment.css("body").first

        body_el ? body_el.prepend_child(banner) : fragment.prepend_child(banner)
      end

      fragment = fragment.css("body").first ? fragment.to_html : "<body>#{fragment.to_html}</body>"
      head_el = "<head>#{paved_email_banner.style}</head>"

      Nokogiri::HTML(head_el + fragment).to_html
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
