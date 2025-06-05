class SamlController < ApplicationController
  include Acapi::Notifiers

  def logout
    redirect_to URI.parse(SamlInformation.saml_logout_url).to_s
  end
end
