RSpec.shared_examples "a software" do |name = "chefdk"|
  let(:project_root) { File.join(tmp_path, "software") }

  let(:name)    { name }
  let(:source)  { nil }
  let(:version) { "1.0.0" }

  let(:build_dir)   { File.join(project_root, "local", "build") }
  let(:cache_dir)   { File.join(project_root, "local", "cache") }
  let(:source_dir)  { File.join(project_root, "local", "source") }
  let(:project_dir) { File.join(source_dir, "project_dir") }

  let(:patches_dir)   { File.join(project_root, "config", "patches", name) }
  let(:scripts_dir)   { File.join(project_root, "config", "scripts", name) }
  let(:softwares_dir) { File.join(project_root, "config", "software", name) }
  let(:templates_dir) { File.join(project_root, "config", "templates", name) }

  let(:install_dir)      { File.join(project_root, "opt", name) }
  let(:bin_dir)          { File.join(install_dir, "bin") }
  let(:embedded_bin_dir) { File.join(install_dir, "embedded", "bin") }

  let(:software) do
    double(Omnibus::Software,
      name:        name,
      version:     version,
      build_dir:   build_dir,
      install_dir: install_dir,
      project_dir: project_dir,
      source:      source,
      overridden?: false)
  end

  before do
    Omnibus::Config.cache_dir(cache_dir)
    Omnibus::Config.source_dir(source_dir)

    Omnibus::Config.project_root(project_root)
    Omnibus::Config.build_retries(0)
    Omnibus::Config.use_git_caching(false)
    Omnibus::Config.software_gems(nil)

    # Make the directories
    FileUtils.mkdir_p(build_dir)
    FileUtils.mkdir_p(cache_dir)
    FileUtils.mkdir_p(project_dir)
    FileUtils.mkdir_p(source_dir)

    FileUtils.mkdir_p(patches_dir)
    FileUtils.mkdir_p(scripts_dir)
    FileUtils.mkdir_p(softwares_dir)
    FileUtils.mkdir_p(templates_dir)

    FileUtils.mkdir_p(install_dir)
    FileUtils.mkdir_p(bin_dir)
    FileUtils.mkdir_p(embedded_bin_dir)

    allow(software).to receive(:with_embedded_path).and_return(
      "PATH" => "#{bin_dir}:#{embedded_bin_dir}:#{ENV["PATH"]}"
    )

    allow(software).to receive(:embedded_bin) do |binary|
      p = File.join(embedded_bin_dir, binary)
      p.gsub!(%r{/}, '\\') if windows?
      p
    end
  end
end
