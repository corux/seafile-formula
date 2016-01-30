require "serverspec"

set :backend, :exec

describe service("seafile") do
  it { should be_enabled }
  it { should be_running }
end

describe port("8082") do
  it { should be_listening }
end

describe service("seahub") do
  it { should be_enabled }
  it { should be_running }
end

describe port("8000") do
  it { should be_listening }
end

describe command("curl -L localhost:8000") do
  its(:stdout) { should match /Private Seafile/ }
end
