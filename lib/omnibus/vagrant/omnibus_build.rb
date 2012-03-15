module Omnibus
module Vagrant
class OmnibusBuild < ::Vagrant::Command::Base

  def execute
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: vagrant omnibus build <vm-name> <project>"
    end

    # parse the options
    argv = parse_options(opts)
    return if !argv
    if argv.length < 2
      raise ::Vagrant::Errors::CLIInvalidUsage, :help => opts.help.chomp
    end

    with_target_vms(argv[0], :single_target => true) do |vm|

      # create / start / resume / provision the vm
      if vm.created?
        if vm.state == :running
          vm.run_action(:provision)
        elsif vm.state == :saved
          vm.run_action(:resume)
          vm.run_action(:provision)
        else # stopped / powered off
          vm.run_action(:start) # also runs provision
        end
      else
        vm.run_action(:up, "provision.enabled" => true)
      end

      path = @env.config.global.omnibus.path
      project = argv[1]
      build_command = "cd #{path} && bundle install && rake projects:#{project}"

      # TODO: add some logging here to indicate that we're starting the build
      exit_status = vm.channel.execute(build_command, :error_check => false) do |type, data|
        # Determine the proper channel to send the output onto depending
        # on the type of data we are receiving.
        channel = type == :stdout ? :out : :error

        # Set the color based on the type of data we are receiving.
        color = type == :stdout ? :green : :red

        # Print the SSH output as it comes in, but don't prefix it and don't
        # force a new line so that the output is properly preserved
        vm.ui.info(data,
                   :prefix => false,
                   :new_line => false,
                   :channel => channel,
                   :color => color)
      end

      # Exit with the exit status we got from executing the command
      exit exit_status
    end
  end

end # OmnibusBuild
end # Vagrant
end # Omnibus
