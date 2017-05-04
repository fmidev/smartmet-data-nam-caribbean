%define smartmetroot /smartmet

Name:           smartmet-data-nam-caribbean
Version:        17.5.4
Release:        1%{?dist}.fmi
Summary:        SmartMet Data NAM Caribbean
Group:          System Environment/Base
License:        MIT
URL:            https://github.com/fmidev/smartmet-data-nam-caribbean
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:	noarch

Requires:	smartmet-qdtools
Requires:	bzip2


%description
SmartMet data ingest module for NAM model Caribbean region.

%prep

%build

%pre

%install
rm -rf $RPM_BUILD_ROOT
mkdir $RPM_BUILD_ROOT
cd $RPM_BUILD_ROOT

mkdir -p .%{smartmetroot}/cnf/cron/{cron.d,cron.hourly}
mkdir -p .%{smartmetroot}/cnf/data
mkdir -p .%{smartmetroot}/tmp/data/nam
mkdir -p .%{smartmetroot}/logs/data
mkdir -p .%{smartmetroot}/run/data/nam/{bin,cnf}

cat > %{buildroot}%{smartmetroot}/cnf/cron/cron.d/nam-caribbean.cron <<EOF
# Model available after
# 00 UTC = 01:40 UTC
50 * * * * utcrun  1 /smartmet/run/data/nam/bin/get_nam_caribbean.sh 
# 06 UTC = 07:40 UTC
50 * * * * utcrun  7 /smartmet/run/data/nam/bin/get_nam_caribbean.sh 
# 12 UTC = 13:40 UTC
50 * * * * utcrun 13 /smartmet/run/data/nam/bin/get_nam_caribbean.sh 
# 18 UTC = 19:40 UTC
50 * * * * utcrun 19 /smartmet/run/data/nam/bin/get_nam_caribbean.sh 
EOF

cat > %{buildroot}%{smartmetroot}/cnf/cron/cron.hourly/clean_data_nam_caribbean <<EOF
#!/bin/sh
# Clean NAM Caribbean data
cleaner -maxfiles 4 '_nam_caribbean_.*_surface.sqd' %{smartmetroot}/data/nam/caribbean
cleaner -maxfiles 4 '_nam_caribbean_.*_pressure.sqd' %{smartmetroot}/data/nam/caribbean
cleaner -maxfiles 4 '_nam_caribbean_.*_surface.sqd' %{smartmetroot}/editor/in
cleaner -maxfiles 4 '_nam_caribbean_.*_pressure.sqd' %{smartmetroot}/editor/in
EOF

cat > %{buildroot}%{smartmetroot}/run/data/nam/cnf/nam-caribbean-surface.st <<EOF
// Precipitation
var prev3 = AVGT(-3, -3, PAR50)
PAR354 = PAR50 - prev3
EOF

cat > %{buildroot}%{smartmetroot}/cnf/data/nam-caribbean.cnf <<EOF
INTERVALS=("0 3 83")
EOF


install -m 755 %{_sourcedir}/smartmet-data-nam-caribbean/get_nam_caribbean.sh %{buildroot}%{smartmetroot}/run/data/nam/bin/

%post

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,smartmet,smartmet,-)
%config(noreplace) %{smartmetroot}/cnf/data/nam-caribbean.cnf
%config(noreplace) %{smartmetroot}/cnf/cron/cron.d/nam-caribbean.cron
%config(noreplace) %attr(0755,smartmet,smartmet) %{smartmetroot}/cnf/cron/cron.hourly/clean_data_nam_caribbean
%{smartmetroot}/*

%changelog
* Thu May 4 2017 Mikko Rauhala <mikko.rauhala@fmi.fi> 17.5.4-1.el7.fmi
- Fixed bugs introduced in previous version

* Wed May 3 2017 Mikko Rauhala <mikko.rauhala@fmi.fi> 17.5.3-1.el7.fmi
- Updated filenaming

* Tue Nov 26 2015 Mikko Rauhala <mikko.rauhala@fmi.fi> 15.11.26-1.el6.fmi
- Fixed precipitation calculations

* Tue Feb 17 2015 Mikko Rauhala <mikko.rauhala@fmi.fi> 15.2.17-2.el6.fmi
- Check size was too big

* Tue Feb 17 2015 Mikko Rauhala <mikko.rauhala@fmi.fi> 15.2.17-1.el6.fmi
- Fixed model run time calculation

* Tue Nov 18 2014 Mikko Rauhala <mikko.rauhala@fmi.fi> 14.11.18-1.el6.fmi
- Initial build 
