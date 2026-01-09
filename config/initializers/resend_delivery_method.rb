require "resend"

module ActionMailer
  module DeliveryMethods
    class ResendDeliveryMethod
      def initialize(settings)
        @settings = settings
        # Ensure API key is set during initialization (for gem's built-in mailer)
        Resend.api_key ||= @settings[:api_key] || ENV["RESEND_KEY"]
      end

      def deliver!(mail)
        # Ensure API key is set (fallback if not set globally)
        Resend.api_key ||= @settings[:api_key] || ENV["RESEND_KEY"]
        
        # Build email parameters
        email_params = {
          from: mail.from.first || @settings[:from] || "onboarding@resend.dev",
          to: Array(mail.to),
          subject: mail.subject
        }
        
        # Add CC if present
        email_params[:cc] = Array(mail.cc) if mail.cc.present?
        
        # Add BCC if present
        email_params[:bcc] = Array(mail.bcc) if mail.bcc.present?
        
        # Add reply-to if present
        email_params[:reply_to] = mail.reply_to.first if mail.reply_to.present?
        
        # Handle multipart emails (HTML and text)
        if mail.multipart?
          email_params[:html] = mail.html_part&.body&.to_s
          email_params[:text] = mail.text_part&.body&.to_s
        else
          # Single part email - determine if HTML or text
          if mail.content_type&.include?("text/html")
            email_params[:html] = mail.body.to_s
          else
            email_params[:text] = mail.body.to_s
          end
        end
        
        # Handle attachments
        if mail.attachments.any?
          email_params[:attachments] = mail.attachments.map do |attachment|
            {
              filename: attachment.filename,
              content: attachment.body.raw_source,
              content_type: attachment.content_type
            }
          end
        end
        
        # Send email via Resend API
        Resend::Emails.send(email_params)
      end
    end
  end
end

