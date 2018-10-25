CKEDITOR.editorConfig = function( config )
{
  $.ajax({
    type:"GET",
    url:"notice_kinds/get_tokens",
    dataType:"json",
    data: {builder: $('#notice_kind_recipient').val()},
    success:function(result){

      config.tokenStart = '#{';
      config.tokenEnd = '}';
      config.availableTokens = result.tokens;

      // config.placeholder_selects = [
      //   config.placeholder_select = {
      //     key: 'placeholder_select',
      //     title: 'Place Holder Select',
      //     placeholders: [{"title":"Loop: Addresses","target":"employer_profile.addresses","iterator":"address","type":"loop"},{"title":"\u0026nbsp;\u0026nbsp; Street 1","target":"address.street_1"},{"title":"\u0026nbsp;\u0026nbsp; Street 2","target":"address.street_2"},{"title":"\u0026nbsp;\u0026nbsp; City","target":"address.city"},{"title":"\u0026nbsp;\u0026nbsp; State","target":"address.state"},{"title":"\u0026nbsp;\u0026nbsp; Zip","target":"address.zip"},{"title":"Loop: Offered products","target":"employer_profile.offered_products","iterator":"offered_product","type":"loop"},{"title":"\u0026nbsp;\u0026nbsp; Product name","target":"offered_product.product_name"},{"title":"\u0026nbsp;\u0026nbsp; Enrollments","target":"offered_product.enrollments"},{"title":"Condition: Broker present?","target":"employer_profile.broker_present?","type":"condition"}]
      //   }
      // ];
    }
  });

  config.tokenStart = '#{';
  config.tokenEnd = '}';

  config.removeButtons = "Form,Checkbox,Radio,TextField,Textarea,Select,Button,ImageButton,HiddenField,About,Print,Save,NewPage,Preview,Save,Language,Flash,Smiley,Image,Iframe";

  config.placeholder_selects = [
      {
        key: 'select_system_settings',
        title: 'Select Application Settings',
        placeholders: [{"title":"Site: Domain name","target":"Settings.site.domain_name"},{"title":"Site: Home url","target":"Settings.site.home_url"},{"title":"Site: Help url","target":"Settings.site.help_url"},{"title":"Site: Faqs url","target":"Settings.site.faqs_url"},{"title":"Site: Main web address","target":"Settings.site.main_web_address"},{"title":"Site: Short name","target":"Settings.site.short_name"},{"title":"Site: Byline","target":"Settings.site.byline"},{"title":"Site: Long name","target":"Settings.site.long_name"},{"title":"Site: Shop find your doctor url","target":"Settings.site.shop_find_your_doctor_url"},{"title":"Site: Document verification checklist url","target":"Settings.site.document_verification_checklist_url"},{"title":"Site: Registration path","target":"Settings.site.registration_path"},{"title":"Contact center: Name","target":"Settings.contact_center.name"},{"title":"Contact center: Alt name","target":"Settings.contact_center.alt_name"},{"title":"Contact center: Phone number","target":"Settings.contact_center.phone_number"},{"title":"Contact center: Fax","target":"Settings.contact_center.fax"},{"title":"Contact center: Tty number","target":"Settings.contact_center.tty_number"},{"title":"Contact center: Alt phone number","target":"Settings.contact_center.alt_phone_number"},{"title":"Contact center: Email address","target":"Settings.contact_center.email_address"},{"title":"Contact center: Small business email","target":"Settings.contact_center.small_business_email"},{"title":"Contact center: Appeals","target":"Settings.contact_center.appeals"},{"title":"Contact center.mailing address: Name","target":"Settings.contact_center.mailing_address.name"},{"title":"Contact center.mailing address: Address 1","target":"Settings.contact_center.mailing_address.address_1"},{"title":"Contact center.mailing address: Address 2","target":"Settings.contact_center.mailing_address.address_2"},{"title":"Contact center.mailing address: City","target":"Settings.contact_center.mailing_address.city"},{"title":"Contact center.mailing address: State","target":"Settings.contact_center.mailing_address.state"},{"title":"Contact center.mailing address: Zip code","target":"Settings.contact_center.mailing_address.zip_code"},{"title":"Aca: State name","target":"Settings.aca.state_name"},{"title":"Aca: State abbreviation","target":"Settings.aca.state_abbreviation"},{"title":"Aca.shop market: Valid employer attestation documents url","target":"Settings.aca.shop_market.valid_employer_attestation_documents_url"},{"title":"Aca.shop market: Binder payment due on","target":"Settings.aca.shop_market.binder_payment_due_on"}]
      },
      {
        key: 'select_conditional_statement',
        title: 'Select Condition/Loop',
        placeholders: [{"title":"Loop: Addresses","target":"employer_profile.addresses","iterator":"address","type":"loop"},{"title":"\u0026nbsp;\u0026nbsp; Street 1","target":"address.street_1"},{"title":"\u0026nbsp;\u0026nbsp; Street 2","target":"address.street_2"},{"title":"\u0026nbsp;\u0026nbsp; City","target":"address.city"},{"title":"\u0026nbsp;\u0026nbsp; State","target":"address.state"},{"title":"\u0026nbsp;\u0026nbsp; Zip","target":"address.zip"},{"title":"Loop: Offered products","target":"employer_profile.offered_products","iterator":"offered_product","type":"loop"},{"title":"\u0026nbsp;\u0026nbsp; Product name","target":"offered_product.product_name"},{"title":"\u0026nbsp;\u0026nbsp; Enrollments","target":"offered_product.enrollments"},{"title":"Condition: Broker present?","target":"employer_profile.broker_present?","type":"condition"}]
      }
     
      ];


  config.extraPlugins = 'button,lineutils,widgetselection,notification,toolbar,widget,dialogui,dialog,clipboard,token,placeholder,placeholder_select';
  config.language = 'en';
};
