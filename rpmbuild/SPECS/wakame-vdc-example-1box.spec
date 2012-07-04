%define _prefix_path opt/axsh
%define _vdc_git_uri git://github.com/axsh/wakame-vdc.git
%define oname wakame-vdc
%define osubname example-1box

# * rpmbuild -bb ./wakame-vdc-example-1box.spec \
# --define "build_id 1.daily"
# --define "build_id $(../helpers/gen-release-id.sh)"

%define release_id 1.daily
%{?build_id:%define release_id %{build_id}}

Name: %{oname}-%{osubname}
Version: 12.03
Release: %{release_id}%{?dist}
Summary: The wakame virtual data center.
Group: Development/Languages
Vendor: Axsh Co. LTD <dev@axsh.net>
URL: http://wakame.jp/
Source: %{_vdc_git_uri}
Prefix: /%{_prefix_path}
License: see https://github.com/axsh/wakame-vdc/blob/master/README.md

%description
<insert long description, indented with spaces>

# example:common
%package common-vmapp-config
Summary: Configuration set for common %{osubname}
Group: Development/Languages
Requires: %{oname}-vdcsh
%description common-vmapp-config
<insert long description, indented with spaces>

# example:dcmgr
%package dcmgr-vmapp-config
Summary: Configuration set for dcmgr %{osubname}
Group: Development/Languages
Requires: %{oname}-dcmgr-vmapp-config
Requires: %{name}-common-vmapp-config
%description dcmgr-vmapp-config
<insert long description, indented with spaces>

# example:hva
%package hva-vmapp-config
Summary: Configuration set for hva %{osubname}
Group: Development/Languages
Requires: %{oname}-hva-full-vmapp-config
Requires: %{name}-common-vmapp-config
%description hva-vmapp-config
<insert long description, indented with spaces>

# example:full
%package full-vmapp-config
Summary: Configuration set for hva %{osubname}
Group: Development/Languages
Requires: %{name}-dcmgr-vmapp-config
Requires: %{name}-hva-vmapp-config
%description full-vmapp-config
<insert long description, indented with spaces>

## rpmbuild -bp
%prep
[ -d %{name}-%{version} ] || git clone %{_vdc_git_uri} %{name}-%{version}
cd %{name}-%{version}
git pull
%setup -T -D

## rpmbuild -bc
%build

## rpmbuid -bi
%install
[ -d ${RPM_BUILD_ROOT} ] && rm -rf ${RPM_BUILD_ROOT}

[ -d ${RPM_BUILD_ROOT}/etc/%{oname} ] || mkdir -p ${RPM_BUILD_ROOT}/etc/%{oname}

# generate /etc/%{oname}/*.conf
config_examples="dcmgr nsa sta"
for config_example in ${config_examples}; do
  cp -p `pwd`/dcmgr/config/${config_example}.conf.example ${RPM_BUILD_ROOT}/etc/%{oname}/${config_example}.conf
done
unset config_examples

VDC_ROOT=/var/lib/%{oname}
config_templates="proxy hva"
for config_template in ${config_templates}; do
  echo "$(eval "echo \"$(cat `pwd`/tests/vdc.sh.d/${config_template}.conf.tmpl)\"")" > ${RPM_BUILD_ROOT}/etc/%{oname}/${config_template}.conf
done
unset config_templates
unset VDC_ROOT

%post dcmgr-vmapp-config
# activate upstart system job
sys_default_confs="auth collector dcmgr metadata nsa proxy sta webui"
for sys_default_conf in ${sys_default_confs}; do
  sed -i s,^#RUN=.*,RUN=yes, /etc/default/vdc-${sys_default_conf}
done

%post hva-vmapp-config
# activate upstart system job
sys_default_confs="hva"
for sys_default_conf in ${sys_default_confs}; do
  sed -i s,^#RUN=.*,RUN=yes, /etc/default/vdc-${sys_default_conf}
done

%clean
rm -rf ${RPM_BUILD_ROOT}

%files common-vmapp-config
%defattr(-,root,root)

%files dcmgr-vmapp-config
%config /etc/%{oname}/dcmgr.conf
%config /etc/%{oname}/nsa.conf
%config /etc/%{oname}/sta.conf
%config /etc/%{oname}/proxy.conf

%files hva-vmapp-config
%config /etc/%{oname}/hva.conf

%files full-vmapp-config

%changelog