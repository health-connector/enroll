module TransportGateway
  class Credentials::ExampleDotComCredential
    def key_credential
      key_file = File.join(File.expand_path("../../..spec/support", __FILE__), "test_files", "key.pem")
      pass_phrase = "it doesn't matter"
      return key_file, pass_phrase
    end

  end
end
