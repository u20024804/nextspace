%define MAKE_VERSION    2.6.8

Name:		nextspace-core
Version:	0.8
Release:	4%{?dist}
Summary:	NextSpace filesystem hierarchy and system files.
License:	GPLv2
URL:		http://gitlab.com/stoyan/nextspace
Source0:	nextspace-core-%{version}.tgz
Source1:	gnustep-make-%{MAKE_VERSION}.tar.gz
Source2:	nextspace.fsl

BuildRequires:  libobjc2-devel

Requires:	libdispatch >= 1.3
Requires:	libobjc2 >= 1.8.2

%description
Includes several components:
- gnustep-make-2.6.7 (/Developer, /Library/Preferences/GNUstep.conf, 
  /usr/NextSpace/Documentation, /usr/NextSpace/bin);
- OS configuration files (/etc: X11 font display config, paths for linker,
  user shell profile, udev rule to mount removable media under /media, 
  /usr/NextSpace/etc/skel: user home dir skeleton);
- GNUstep helper script: /usr/NextSpace/bin/GNUstepServices.

%package devel
Summary:	Development header files for NextSpace core components.
Requires:	%{name}%{?_isa} = %{version}-%{release}
Requires:	libdispatch-devel
Requires:	libobjc2-devel
Provides:	gnustep-make

%description devel
Development files for libdispatch (includes kqueue and pthread_workqueue) 
and libobjc. Also contains gnustep-make-2.6.7 to build nextspace-runtime and
develop applications/tools for NextSpace environment.

%prep
%setup -c -n nextspace-core -a 1
cp %{_sourcedir}/nextspace.fsl %{_builddir}/%{name}/gnustep-make-%{MAKE_VERSION}/FilesystemLayouts/nextspace

%build
export CC=clang
export CXX=clang++
export LD_LIBRARY_PATH="%{buildroot}/Library/Libraries:/usr/NextSpace/lib"

# Build gnustep-make to include in -devel package
cd gnustep-make-%{MAKE_VERSION}
./configure \
    --with-config-file=/Library/Preferences/GNUstep.conf \
    --with-layout=nextspace \
    --enable-native-objc-exceptions \
    --with-thread-lib=-lpthread \
    --enable-objc-nonfragile-abi \
    --enable-debug-by-default
make
cd ..

%install
cd gnustep-make-%{MAKE_VERSION}
%{make_install} GNUSTEP_INSTALLATION_DOMAIN=NETWORK
rm %{buildroot}/usr/NextSpace/bin/opentool
cd ..

cd nextspace-core-%{version}
cp -vr ./* %{buildroot}
mkdir %{buildroot}/Users
rm -r %{buildroot}/usr/share

%files 
/Library
/Users
/etc
/usr/NextSpace/Documentation/man/man1/open*.gz
/usr/NextSpace/etc/
/usr/NextSpace/bin/GNUstepServices
/usr/NextSpace/bin/openapp

%files devel
/Developer
/usr/NextSpace/bin/debugapp
/usr/NextSpace/bin/gnustep-config
/usr/NextSpace/bin/gnustep-tests
/usr/NextSpace/Documentation/man/man1/debugapp*
/usr/NextSpace/Documentation/man/man1/gnustep*
/usr/NextSpace/Documentation/man/man7/GNUstep*.gz
/usr/NextSpace/Documentation/man/man7/library-combo*

%changelog
* Wed Oct 19 2016 Sergii Stoian <stoyan255@ukr.net> 0.8-1
- Initial spec.
