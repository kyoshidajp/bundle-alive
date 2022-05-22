# frozen_string_literal: true

require "spec_helper"

RSpec.describe Bundler::Alive::Client::GemsApiClient do
  describe "#new" do
    context "with `config_path`" do
      let!(:config) { "spec/fixtures/files/.bundler-alive.yml" }
      let!(:client) { described_class.new(config) }
      it "has merged `@config_gems`" do
        config_gems = client.instance_variable_get(:@config_gems)
        expect(config_gems.keys).to eq %w[fog-sakuracloud gli]
      end
    end
  end

  describe "#get_source_code_url" do
    let!(:config) { "spec/fixtures/files/.bundler-alive.yml" }
    let!(:client) { described_class.new(config) }
    context "with a exists gem on gems.org" do
      it "returns a `SourceCodeRepositoryUrl`" do
        VCR.use_cassette "rubygems.org/api/v1/gems/rails" do
          url = client.send(:get_repository_url, "rails")
          expect(url).to be_a_kind_of(SourceCodeRepositoryUrl)
          expect(url.url).to eq "https://github.com/rails/rails/tree/v7.0.3"
        end
      end
    end

    context "with a not exists gem on gems.org" do
      it "raises a `Client::GemsApi::NotFound`" do
        VCR.use_cassette "rubygems.org/api/v1/gems/not-found-gem" do
          expect do
            client.send(:get_repository_url, "not-found-gem")
          end.to raise_error(Client::GemsApiClient::NotFound)
        end
      end
    end
  end

  describe "#gems_api_response" do
    let!(:config) { "spec/fixtures/files/.bundler-alive.yml" }
    let!(:client) { described_class.new(config) }
    context "all gems are found" do
      it "returns a `Client::GemsApiResponse`" do
        VCR.use_cassette "rubygems.org/multi_search" do
          gems_api_response = client.gems_api_response(%w[ast journey parallel parser rainbow])
          expected = {
            github:
              [
                SourceCodeRepositoryUrl.new("https://github.com/whitequark/ast", "ast"),
                SourceCodeRepositoryUrl.new("https://github.com/rails/journey", "journey"),
                SourceCodeRepositoryUrl.new("https://github.com/grosser/parallel/tree/v1.22.1", "parallel"),
                SourceCodeRepositoryUrl.new("https://github.com/whitequark/parser/tree/v3.1.2.0", "parser"),
                SourceCodeRepositoryUrl.new("https://github.com/sickill/rainbow", "rainbow")
              ]
          }
          expect(gems_api_response).to be_an_instance_of(Client::GemsApiResponse)

          service_with_urls = gems_api_response.service_with_urls
          expect(service_with_urls.keys).to eq expected.keys
          expect(service_with_urls[:github].map(&:url)).to eq expected[:github].map(&:url)
        end
      end
    end

    context "when having urls in configgems" do
      it "returns a `Client::GemsApiResponse`" do
        VCR.use_cassette "rubygems.org/multi_search" do
          gems_api_response = client.gems_api_response(%w[ast fog-sakuracloud gli journey parallel parser rainbow])
          expected = {
            github:
              [
                SourceCodeRepositoryUrl.new("https://github.com/whitequark/ast", "ast"),
                SourceCodeRepositoryUrl.new("https://github.com/fog/fog-sakuracloud", "fog-sakuracloud"),
                SourceCodeRepositoryUrl.new("https://github.com/davetron5000/gli", "gli"),
                SourceCodeRepositoryUrl.new("https://github.com/rails/journey", "journey"),
                SourceCodeRepositoryUrl.new("https://github.com/grosser/parallel/tree/v1.22.1", "parallel"),
                SourceCodeRepositoryUrl.new("https://github.com/whitequark/parser/tree/v3.1.2.0", "parser"),
                SourceCodeRepositoryUrl.new("https://github.com/sickill/rainbow", "rainbow")
              ]
          }
          expect(gems_api_response).to be_an_instance_of(Client::GemsApiResponse)

          service_with_urls = gems_api_response.service_with_urls
          expect(service_with_urls.keys).to eq expected.keys
          expect(service_with_urls[:github].map(&:url)).to eq expected[:github].map(&:url)
        end
      end
    end

    context "when includes not found gems" do
      it "returns only found gems result" do
        VCR.use_cassette "rubygems.org/api/v1/gems/ast" do
          VCR.use_cassette "rubygems.org/api/v1/gems/not-found-gem" do
            gems_api_response = client.gems_api_response(%w[ast not-found-gem])
            expected = {
              github:
                [
                  SourceCodeRepositoryUrl.new("https://github.com/whitequark/ast", "ast")
                ]
            }
            expect(gems_api_response).to be_an_instance_of(Client::GemsApiResponse)
            expect(gems_api_response.error_messages).to eq ["[not-found-gem] Not found in RubyGems.org."]

            service_with_urls = gems_api_response.service_with_urls
            expect(service_with_urls.keys).to eq expected.keys
            expect(service_with_urls[:github].map(&:url)).to eq expected[:github].map(&:url)
          end
        end
      end
    end

    context "when includes gem which has not supported url" do
      it "returns only found gems result" do
        VCR.use_cassette "rubygems.org/api/v1/gems/atlassian-jwt" do
          gems_api_response = client.gems_api_response(%w[atlassian-jwt])

          expect(gems_api_response).to be_an_instance_of(Client::GemsApiResponse)
          message = "[atlassian-jwt] Source code repository is not found in RubyGems.org,"\
                    " or not supported. URL: https://rubygems.org/gems/atlassian-jwt"
          expect(gems_api_response.error_messages).to eq [message]

          service_with_urls = gems_api_response.service_with_urls
          expect(service_with_urls.keys).to eq []
        end
      end
    end
  end
end
