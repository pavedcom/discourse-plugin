# name: paved-email-banner	
# version: 0.1.6	
# author: Paved (hey@paved.com)	
# url: https://github.com/pavedcom/discourse-plugin

enabled_site_setting :paved_email_banner_enabled

after_initialize {

  SiteSetting.strip_images_from_short_emails = false

  class ::PavedEmailBanner

    def initialize(message)
      @message = message
      @random_id = SecureRandom.alphanumeric
    end

    def banner
      <<~HTML
      <table style="width:100%">
        <tr>
          <td align="center">
            <a href="#{desktop_banner_click_url}" style="display:none" id="desktop">
              <span id="pad-img-desktop" style="display:block;background-repeat: no-repeat !important;background-position: center !important;"></span> 
            </a>

            <a href="#{mobile_banner_click_url}" id="mobile">
              <span id="pad-img-mobile" style="display:block;background-repeat: no-repeat !important;background-position: center !important;"></span> 
            </a>
          </td>
        </tr>
      </table>
      HTML
    end

    def html
      style + banner
    end

    def style
      <<~HTML
        <style>
          @media only screen and (max-device-width: 489px) {
            #pad-img-mobile {
              background-image: url(#{mobile_banner_img_url}) !important;
              width: #{SiteSetting.paved_email_banner_mobile_adzone_width}px !important;
              height: #{SiteSetting.paved_email_banner_mobile_adzone_height}px !important;
            }
            desktop {display: none !important;}
          }

          @media only screen and (min-device-width: 490px) {
            #pad-img-desktop {
              background-image: url(#{desktop_banner_img_url}) !important;
              width: #{SiteSetting.paved_email_banner_desktop_adzone_width}px !important;
              height: #{SiteSetting.paved_email_banner_desktop_adzone_height}px !important;
            }
            #mobile {display: none !important;}
            #desktop {display: unset !important;}
          }
        </style>
      HTML
    end

    private

      def email_address
        @message.to ? @message.to[0] : nil
      end

      def desktop_banner_click_url
        "https://pa.pvd.to/click/#{SiteSetting.paved_email_banner_desktop_adzone_key}?email=#{email_address}&campaign_id=#{@random_id}"
      end

      def mobile_banner_click_url
        "https://pa.pvd.to/click/#{SiteSetting.paved_email_banner_mobile_adzone_key}?email=#{email_address}&campaign_id=#{@random_id}"
      end

      def desktop_banner_img_url
        "https://pa.pvd.to/serve/#{SiteSetting.paved_email_banner_desktop_adzone_key}?email=#{email_address}&campaign_id=#{@random_id}"
      end

      def mobile_banner_img_url
        "https://pa.pvd.to/serve/#{SiteSetting.paved_email_banner_mobile_adzone_key}?email=#{email_address}&campaign_id=#{@random_id}"
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


