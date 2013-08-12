Puppet::Type.newtype(:rabbitmq_user) do
  desc 'Native type for managing rabbitmq users'

  ensurable do
    defaultto(:present)
    newvalue(:present) do
      provider.create
    end
    newvalue(:absent) do
      provider.destroy
    end
  end

  newparam(:name, :namevar => true) do
    desc 'Name of user'
    newvalues(/^\S+$/)
  end

  # newproperty(:password) do
  newparam(:password) do
    desc 'User password to be set *on creation*'
  end

  newproperty(:admin) do
    desc 'rather or not user should be an admin'
    newvalues(/true|false/)
    munge do |value|
      # converting to_s incase its a boolean
      value.to_s.to_sym
    end
    defaultto :false
  end

  newproperty(:tags) do
    desc "User's tags value  Cannot be combined with admin property."
    defaultto :nil
  end

  validate do
    if self[:ensure] == :present and ! self[:password]
      raise ArgumentError, 'must set password when creating user' unless self[:password]
    end
    if self[:admin] and self[:tags]
      raise ArgumentError, 'Cannot use both admin and tags.'
    end
  end

end
