require "spec_helper"

module Omnibus
  class RandomClass
    include Templating
  end

  describe Templating do
    subject { RandomClass.new }

    describe '#render_template' do
      let(:source)      { File.join(tmp_path, "source.erb") }
      let(:destination) { File.join(tmp_path, "final") }
      let(:mode)        { 0644 }
      let(:variables)   { { name: "Name" } }
      let(:contents) do
        <<-EOH.gsub(/^ {10}/, "")
          <%= name %>

          <% if false -%>
            This is magic!
          <% end -%>
        EOH
      end

      let(:options) do
        {
          destination: destination,
          variables:   variables,
          mode:        mode,
        }
      end

      before do
        File.open(source, "w") { |f| f.write(contents) }
      end

      context "when no destination is given" do
        let(:destination) { nil }

        it "renders adjacent, without the erb extension" do
          subject.render_template(source, options)
          expect(File.join(tmp_path, "source")).to be_a_file
        end
      end

      context "when a destination is given" do
        it "renders at the destination" do
          subject.render_template(source, options)
          expect(destination).to be_a_file
        end
      end

      context "when a mode is given", :not_supported_on_windows do
        let(:mode) { 0755 }

        it "renders the object with the mode" do
          subject.render_template(source, options)
          expect(destination).to be_an_executable
        end
      end

      context "when an undefined variable is used" do
        let(:contents) { "<%= not_a_real_variable %>" }

        it "raise an exception" do
          expect do
            subject.render_template(source, options)
          end.to raise_error(NameError)
        end
      end

      context "when no variables are present" do
        let(:content)   { "static content" }
        let(:variables) { {} }

        it "renders the template" do
          subject.render_template(source, options)
          expect(destination).to be_a_file
        end
      end
    end
  end
end
