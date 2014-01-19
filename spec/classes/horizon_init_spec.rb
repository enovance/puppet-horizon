require 'spec_helper'

describe 'horizon' do
  let :pre_condition do
    'include apache'
  end

  let :fixtures_path do
    File.expand_path(File.join(__FILE__, '..', '..', 'fixtures'))
  end

  let :default_facts do
    { :concat_basedir => '/var/lib/puppet/concat' }
  end

  let :default_params do
    { :secret_key     => 'elj1IWiLoWHgcyYxFVLj7cM5rGOOxWl0',
      :fqdn           => '*',
      :wsgi_processes => '3',
      :wsgi_threads   => '10',
    }
  end



    {
      'Debian' => {
        :osfamily               => 'Debian',
        :operatingsystemrelease => '7',
        :httpd_config_file      => '/etc/apache2/conf.d/openstack-dashboard.conf',
        :config_file            => '/etc/openstack-dashboard/local_settings.py',
        :package_name           => 'openstack-dashboard-apache',
        :http_service           => 'apache2',
        :root_url               => '/horizon',
        :wsgi_user              => 'dashboard',
        :wsgi_group             => 'dashboard',

      },
      'Ubuntu' => {
        :osfamily               => 'Debian',
        :operatingsystemrelease => '12',
        :httpd_config_file      => '/etc/apache2/conf.d/openstack-dashboard.conf',
        :config_file            => '/etc/openstack-dashboard/local_settings.py',
        :package_name           => 'openstack-dashboard',
        :http_service           => 'apache2',
        :root_url               => '/horizon',
        :wsgi_user              => 'dashboard',
        :wsgi_group             => 'dashboard',
      },
      'RedHat' => {
        :osfamily               => 'RedHat',
        :operatingsystemrelease => '6',
        :httpd_config_file      => '/etc/httpd/conf.d/openstack-dashboard.conf',
        :config_file            => '/etc/openstack-dashboard/local_settings',
        :package_name           => 'openstack-dashboard',
        :http_service           => 'httpd',
        :root_url               => '/dashboard',
        :wsgi_user              => 'dashboard',
        :wsgi_group             => 'dashboard',
      }
    }.each do |operatingsystem, osparams|

    describe "on #{operatingsystem}" do
      let(:facts) do {
          :operatingsystem        => operatingsystem,
          :osfamily               => osparams[:osfamily],
          :operatingsystemrelease => osparams[:operatingsystemrelease]
        }.merge default_facts
      end


      let(:params) do {
          :root_url               => osparams[:root_url],
          :wsgi_user              => osparams[:wsgi_user],
          :wsgi_group             => osparams[:wsgi_group],
        }.merge default_params
      end


      it { should contain_service('httpd').with_name(osparams[:http_service]) }
      it { should contain_file(osparams[:httpd_config_file]) }
      it { should contain_file(osparams[:config_file]) }

      describe 'with default parameters' do
        it { should contain_package('horizon').with_ensure('present') }
        it 'generates local_settings.py' do
          verify_contents(subject, osparams[:config_file], [
            'DEBUG = False',
            "ALLOWED_HOSTS = ['*', ]",
            "SECRET_KEY = 'elj1IWiLoWHgcyYxFVLj7cM5rGOOxWl0'",
            'OPENSTACK_KEYSTONE_URL = "http://127.0.0.1:5000/v2.0"',
            'OPENSTACK_KEYSTONE_DEFAULT_ROLE = "_member_"',
            "    'can_set_mount_point': True,",
            'API_RESULT_LIMIT = 1000',
            "LOGIN_URL = '#{osparams[:root_url]}/auth/login/'",
            "LOGOUT_URL = '#{osparams[:root_url]}/auth/logout/'",
            "LOGIN_REDIRECT_URL = '#{osparams[:root_url]}'"
          ])
        end

        it 'openstack-dashboard.conf' do

          verify_contents(subject, osparams[:httpd_config_file], [
            "WSGIScriptAlias #{osparams[:root_url]} /usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi",
            "WSGIDaemonProcess horizon user=#{osparams[:wsgi_user]} group=#{osparams[:wsgi_group]} processes=#{params[:wsgi_processes]} threads=#{params[:wsgi_threads]}",
            "WSGIProcessGroup #{osparams[:wsgi_group]}",
            "RedirectMatch permanent ^/$ #{osparams[:root_url]}/",
          ])
        end
      end

      describe 'when overriding parameters' do
        before do
          params.merge!({
            :cache_server_ip       => '10.0.0.1',
            :keystone_host         => 'keystone.example.com',
            :keystone_port         => 4682,
            :keystone_scheme       => 'https',
            :keystone_default_role => 'SwiftOperator',
            :keystone_url          => false,
            :django_debug          => true,
            :api_result_limit      => 4682,
            :can_set_mount_point   => false,
          })
        end

        it 'generates local_settings.py' do
          verify_contents(subject, osparams[:config_file], [
            'DEBUG = True',
            "ALLOWED_HOSTS = ['*', ]",
            "SECRET_KEY = 'elj1IWiLoWHgcyYxFVLj7cM5rGOOxWl0'",
            'OPENSTACK_HOST = "keystone.example.com"',
            'OPENSTACK_KEYSTONE_URL = "https://%s:4682/v2.0" % OPENSTACK_HOST',
            'OPENSTACK_KEYSTONE_DEFAULT_ROLE = "SwiftOperator"',
            "    'can_set_mount_point': False,",
            'API_RESULT_LIMIT = 4682'
          ])
        end
      end
      describe 'with overriding local_settings_template' do
        before do
          params.merge!({
            :django_debug            => 'True',
            :help_url                => 'https://docs.openstack.org',
            :local_settings_template => fixtures_path + '/override_local_settings.py.erb'
          })
        end

        it 'uses the custom local_settings.py template' do
          verify_contents(subject, osparams[:config_file], [
            '# Custom local_settings.py',
            'DEBUG = True',
            "HORIZON_CONFIG = {",
            "    'dashboards': ('project', 'admin', 'settings',),",
            "    'default_dashboard': 'project',",
            "    'user_home': 'openstack_dashboard.views.get_user_home',",
            "    'ajax_queue_limit': 10,",
            "    'auto_fade_alerts': {",
            "        'delay': 3000,",
            "        'fade_duration': 1500,",
            "        'types': ['alert-success', 'alert-info']",
            "    },",
            "    'help_url': \"https://docs.openstack.org\",",
            "    'exceptions': {'recoverable': exceptions.RECOVERABLE,",
            "                   'not_found': exceptions.NOT_FOUND,",
            "                   'unauthorized': exceptions.UNAUTHORIZED},",
            "}",
          ])
        end
      end

      describe 'when overriding keystone_url' do
        before do
          params.merge!({
            :keystone_url => 'https://identity.example.com/public/endpoint/v2.0'
          })
        end

        it 'generates local_settings.py' do
          verify_contents(subject, osparams[:config_file], [
            'DEBUG = False',
            "ALLOWED_HOSTS = ['*', ]",
            "SECRET_KEY = 'elj1IWiLoWHgcyYxFVLj7cM5rGOOxWl0'",
            'OPENSTACK_KEYSTONE_URL = "https://identity.example.com/public/endpoint/v2.0"',
            'OPENSTACK_KEYSTONE_DEFAULT_ROLE = "_member_"',
            "    'can_set_mount_point': True,",
            'API_RESULT_LIMIT = 1000',
            "LOGIN_URL = '#{osparams[:root_url]}/auth/login/'",
            "LOGOUT_URL = '#{osparams[:root_url]}/auth/logout/'",
            "LOGIN_REDIRECT_URL = '#{osparams[:root_url]}'"
          ])
        end
      end

      describe 'when ssl is enabled' do
        before do
          params.merge!({
            :listen_ssl => true,
            :horizon_cert => '/etc/ssl/localcerts/apache.crt',
            :horizon_key => '/etc/ssl/localcerts/apache.key',
            :horizon_ca => '/etc/ssl/localcerts/ca.crt',
          })
        end

        it { should contain_file_line('httpd_sslcert_path').with(
           :line => "SSLCertificateFile /etc/ssl/localcerts/apache.crt"
        )}
        it { should contain_file_line('httpd_sslkey_path').with(
           :line => "SSLCertificateKeyFile /etc/ssl/localcerts/apache.key"
        )}
      end

      describe 'with openstack_endpoint_type' do
        before do
          params.merge!({
            :openstack_endpoint_type => 'internalURL',
          })
        end

        it 'generates local_settings.py' do
          verify_contents(subject, osparams[:config_file], [
            'OPENSTACK_ENDPOINT_TYPE = "internalURL"',
          ])
        end
      end

      describe 'with secondary_endpoint_type' do
        before do
          params.merge!({
            :secondary_endpoint_type => 'ANY-VALUE',
          })
        end

        it 'generates local_settings.py' do
          verify_contents(subject, osparams[:config_file], [
            'SECONDARY_ENDPOINT_TYPE = "ANY-VALUE"',
          ])
        end
      end
    end
  end
end
