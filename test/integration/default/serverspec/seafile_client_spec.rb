require "serverspec"

set :backend, :exec

describe command("which seafile-applet") do
  its(:exit_status) { should eq 0 }
end
