# name: paved-email-banner
# version: 0.1.0
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
        <<~HTML
          <div class="paved-banner banner-#{size}">
            <a href="#{banner_url}" class="paved-banner banner-#{size}" title="">
              <span class="banner-#{size}">
                <img class="paved-banner-img banner-#{size}" src="#{banner_img(size)}" alt="" width="" height="" />
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

            .paved-banner {
              display: block;
              width: 100% !important;
            }

            .paved-banner-img {
              width: 100% !important;
              height: auto !important;
            }

            @media only screen and (max-device-width:480px) {
              .banner-desktop {
                display: none !important;
              }
            }

            @media only screen and (min-device-width:481px) {
              .banner-mobile {
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

      fragment  = Nokogiri::HTML.fragment(html_str)
      body_el   = fragment.css("body").first
      banner    = PavedEmailBanner.new(@message).html

      if body_el
        body_el.prepend_child(banner)
      else
        fragment.prepend_child(banner)
      end

      fragment.to_html

    end

  }

}
