# frozen_string_literal: true

require 'rails_helper'

describe MailDelivery::SoaMailer do
  let(:mailer) { MailDelivery::SoaMailer.new }
  let(:recipient) { 'test@example.com' }

  describe '#deliver!' do
    context 'when subject contains accented characters' do
      it 'transliterates the subject to unaccented characters' do
        # Create a mock mail object with accented subject
        mail = double('mail')
        allow(mail).to receive(:subject).and_return('Fédéral Héalth Ëligibility')
        allow(mail).to receive(:body).and_return(double('body', raw_source: 'Test body'))
        allow(mail).to receive(:to).and_return([recipient])

        expect(mailer).to receive(:send_email_html).with(recipient, 'Federal Health Eligibility', 'Test body')

        mailer.deliver!(mail)
      end

      it 'converts accented French characters' do
        mail = double('mail')
        allow(mail).to receive(:subject).and_return('Réunion Café Assurance')
        allow(mail).to receive(:body).and_return(double('body', raw_source: 'Body content'))
        allow(mail).to receive(:to).and_return([recipient])

        expect(mailer).to receive(:send_email_html).with(recipient, 'Reunion Cafe Assurance', 'Body content')

        mailer.deliver!(mail)
      end

      it 'converts accented Spanish characters' do
        mail = double('mail')
        allow(mail).to receive(:subject).and_return('Año Nuevo Ñoño')
        allow(mail).to receive(:body).and_return(double('body', raw_source: 'Body content'))
        allow(mail).to receive(:to).and_return([recipient])

        expect(mailer).to receive(:send_email_html).with(recipient, 'Ano Nuevo Nono', 'Body content')

        mailer.deliver!(mail)
      end

      it 'converts multiple accented characters in a single subject' do
        mail = double('mail')
        allow(mail).to receive(:subject).and_return('Être Médecin à l\'Époque')
        allow(mail).to receive(:body).and_return(double('body', raw_source: 'Body content'))
        allow(mail).to receive(:to).and_return([recipient])

        expect(mailer).to receive(:send_email_html).with(recipient, 'Etre Medecin a l\'Epoque', 'Body content')

        mailer.deliver!(mail)
      end
    end

    context 'when subject is blank' do
      it 'does not transliterate blank subject' do
        mail = double('mail')
        allow(mail).to receive(:subject).and_return('')
        allow(mail).to receive(:body).and_return(double('body', raw_source: 'Body content'))
        allow(mail).to receive(:to).and_return([recipient])

        expect(mailer).to receive(:send_email_html).with(recipient, '', 'Body content')

        mailer.deliver!(mail)
      end

      it 'does not transliterate nil subject' do
        mail = double('mail')
        allow(mail).to receive(:subject).and_return(nil)
        allow(mail).to receive(:body).and_return(double('body', raw_source: 'Body content'))
        allow(mail).to receive(:to).and_return([recipient])

        expect(mailer).to receive(:send_email_html).with(recipient, nil, 'Body content')

        mailer.deliver!(mail)
      end
    end

    context 'when subject has no accented characters' do
      it 'preserves unaccented subject' do
        mail = double('mail')
        allow(mail).to receive(:subject).and_return('Regular Health Notice')
        allow(mail).to receive(:body).and_return(double('body', raw_source: 'Body content'))
        allow(mail).to receive(:to).and_return([recipient])

        expect(mailer).to receive(:send_email_html).with(recipient, 'Regular Health Notice', 'Body content')

        mailer.deliver!(mail)
      end
    end

    context 'when mail has multiple recipients' do
      it 'sends transliterated subject to each recipient' do
        mail = double('mail')
        recipients = ['recipient1@example.com', 'recipient2@example.com', 'recipient3@example.com']
        allow(mail).to receive(:subject).and_return('Assurance Santé')
        allow(mail).to receive(:body).and_return(double('body', raw_source: 'Body content'))
        allow(mail).to receive(:to).and_return(recipients)

        recipients.each do |recipient_email|
          expect(mailer).to receive(:send_email_html).with(recipient_email, 'Assurance Sante', 'Body content')
        end

        mailer.deliver!(mail)
      end
    end

    context 'when body contains accented characters' do
      it 'does not transliterate body content' do
        mail = double('mail')
        allow(mail).to receive(:subject).and_return('Test Sübject')
        allow(mail).to receive(:body).and_return(double('body', raw_source: 'Bödÿ çöñtëñt'))
        allow(mail).to receive(:to).and_return([recipient])

        expect(mailer).to receive(:send_email_html).with(recipient, 'Test Subject', 'Bödÿ çöñtëñt')

        mailer.deliver!(mail)
      end
    end
  end
end
