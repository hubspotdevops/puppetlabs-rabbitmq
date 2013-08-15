require 'puppet'
Puppet::Type.type(:rabbitmq_user).provide(:rabbitmqctl) do

  if Puppet::PUPPETVERSION.to_f < 3
    commands :rabbitmqctl => 'rabbitmqctl'
  else
     has_command(:rabbitmqctl, 'rabbitmqctl') do
       environment :HOME => "/tmp"
     end
  end

  defaultfor :feature => :posix

  def self.instances
    rabbitmqctl('list_users').split(/\n/)[1..-2].collect do |line|
      if line =~ /^(\S+)(\s+\S+|)$/
        new(:name => $1)
      else
        raise Puppet::Error, "Cannot parse invalid user line: #{line}"
      end
    end
  end

  def create
    rabbitmqctl('add_user', resource[:name], resource[:password])
    if resource[:admin] == :true
      make_user_admin()
    end
    if resource[:user_tags] != ''
      set_user_tags()
    end
  end

  def destroy
    rabbitmqctl('delete_user', resource[:name])
  end

  def exists?
    out = rabbitmqctl('list_users').split(/\n/)[1..-2].detect do |line|
      line.match(/^#{Regexp.escape(resource[:name])}(\s+\S+|)$/)
    end
  end

  # def password
  # def password=()
  def admin
    match = rabbitmqctl('list_users').split(/\n/)[1..-2].collect do |line|
      line.match(/^#{Regexp.escape(resource[:name])}\s+(\[|\[.*,)(administrator)?(,.*\]|\])/)
    end.compact.first
    if match
      (:true if match[1].to_s == 'administrator') || :false
    else
      raise Puppet::Error, "Could not match line '#{resource[:name]} (true|false)' from list_users (perhaps you are running on an older version of rabbitmq that does not support admin users?)"
    end
  end

  def user_tags
    if resource[:user_tags] != ''
      list_users_result = rabbitmqctl('list_users')
      user_tags_line = list_users_result.split(/\n/)[1..-2].detect do |line|
        line.match(/^#{Regexp.escape(resource[:name])}(\s+\S+|)$/)
      end

      user_tags_match_data = user_tags_line.match(/^#{Regexp.escape(resource[:name])}\s+\[(.*)\]/)
      if user_tags_match_data
        current_tags = user_tags_match_data[1].split(',')
        return current_tags
      else
        raise Puppet::Error, "Could not match line '#{resource[:name]} ' from list_users (perhaps the user does not exists?)"
      end
    end
  end

  def admin=(state)
    if state == :true
      make_user_admin()
    elsif state == :false && resource[:user_tags] == ''
      unmake_user_admin()
    end
  end

  def user_tags=(tag_list)
    if tag_list.sort != self.user_tags.sort
      set_user_tags(tag_list)
    end
  end

  def make_user_admin
    rabbitmqctl('set_user_tags', resource[:name], 'administrator')
  end

  def unmake_user_admin
    rabbitmqctl('set_user_tags', resource[:name], '')
  end

  def set_user_tags(tag_list)
    tag_list_str = tag_list.sort.join(',')
    rabbitmqctl('set_user_tags', resource[:name], tag_list_str)
  end

end
