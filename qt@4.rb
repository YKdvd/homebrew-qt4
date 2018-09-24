class QtAT4 < Formula
  desc "Cross-platform application and UI framework"
  homepage "https://www.qt.io/"
  url "https://download.qt.io/archive/qt/4.8/4.8.7/qt-everywhere-opensource-src-4.8.7.tar.gz"
  mirror "https://mirrors.ocf.berkeley.edu/qt/archive/qt/4.8/4.8.7/qt-everywhere-opensource-src-4.8.7.tar.gz"
  sha256 "e2882295097e47fe089f8ac741a95fef47e0a73a3f3cdf21b56990638f626ea0"
  revision 5

  head "https://code.qt.io/qt/qt.git", :branch => "4.8"

  # Backport of Qt5 commit to fix the fatal build error with Xcode 7, SDK 10.11.
  # https://code.qt.io/cgit/qt/qtbase.git/commit/?id=b06304e164ba47351fa292662c1e6383c081b5ca
  patch do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/480b7142c4e2ae07de6028f672695eb927a34875/qt/el-capitan.patch"
    sha256 "c8a0fa819c8012a7cb70e902abb7133fc05235881ce230235d93719c47650c4e"
  end
  
  # Backport of Qt5 patch to fix an issue with null bytes in QSetting strings.
  patch do
    url "https://raw.githubusercontent.com/cartr/homebrew-qt4/41669527a2aac6aeb8a5eeb58f440d3f3498910a/patches/qsetting-nulls.patch"
    sha256 "0deb4cd107853b1cc0800e48bb36b3d5682dc4a2a29eb34a6d032ac4ffe32ec3"
  end
  
  # Patch to fix build on macOS High Sierra
  patch :p0 do
    url "https://raw.githubusercontent.com/cartr/homebrew-qt4/c957b2d755c762b77142e35f68cddd7f0986bc7b/patches/qt4-versions-without-underscores.patch"
    sha256 "69713c9bcedace4c167273822da14247760c6dcff4949251af6a7b5f93bca9aa"
  end

  # Patch for stricter compiler restrictions on High Sierra
  patch :p0 do
    url "https://raw.githubusercontent.com/cartr/homebrew-qt4/c957b2d755c762b77142e35f68cddd7f0986bc7b/patches/linguist-findmessage-null-check.patch"
    sha256 "db68bf8397eb404c9620c6bb1ada5e98369420b1ea44f2da8c43c718814b5b3b"
  end

  # Patch for QFixed compiler issue in QCoreTextFontEngine
  patch :p1 do
    url "https://raw.githubusercontent.com/cartr/homebrew-qt4/22a6e328b6d911b3c1cedcaadb2882dda728f8a7/patches/qfixed.patch"
    sha256 "4ca3df71470f755917bc903dfee0b6a6e1d2788322b9d71d810b3bb80b3f8c8a"
  end

  # Patch for spurious QObject warnings
  patch :p1 do
    url "https://raw.githubusercontent.com/cartr/homebrew-qt4/b7bc7818aa11c809209032554a990b1cef7edacc/patches/qobject-spurious-warnings.patch"
    sha256 "5e81df9a1c35a5aec21241a82707ad6ac198b2e44928389722b64da341260c5d"
  end

  option "with-docs", "Build documentation"

  depends_on "openssl"
  depends_on "dbus" => :optional
  depends_on "mysql" => :optional
  depends_on "postgresql" => :optional

  deprecated_option "qtdbus" => "with-dbus"
  deprecated_option "with-d-bus" => "with-dbus"

  resource "test-project" do
    url "https://gist.github.com/tdsmith/f55e7e69ae174b5b5a03.git",
        :revision => "6f565390395a0259fa85fdd3a4f1968ebcd1cc7d"
  end

  def install
    args = %W[
      -prefix #{prefix}
      -plugindir #{prefix}/lib/qt4/plugins
      -importdir #{prefix}/lib/qt4/imports
      -datadir #{prefix}/etc/qt4
      -release
      -opensource
      -confirm-license
      -fast
      -system-zlib
      -qt-libtiff
      -qt-libpng
      -qt-libjpeg
      -nomake demos
      -nomake examples
      -cocoa
      -no-webkit
      -qt3support
    ]

    if ENV.compiler == :clang
      args << "-platform"

      if MacOS.version >= :mavericks
        args << "unsupported/macx-clang-libc++"
      else
        args << "unsupported/macx-clang"
      end
    end

    # Phonon is broken on macOS 10.12+ and Xcode 8+ due to QTKit.framework
    # being removed.
    # args << "-no-phonon" if MacOS.version >= :sierra || MacOS::Xcode.version >= "8.0"

    args << "-openssl-linked"
    args << "-I" << Formula["openssl"].opt_include
    args << "-L" << Formula["openssl"].opt_lib

    args << "-plugin-sql-mysql" if build.with? "mysql"
    args << "-plugin-sql-psql" if build.with? "postgresql"

    if build.with? "dbus"
      dbus_opt = Formula["dbus"].opt_prefix
      args << "-I#{dbus_opt}/lib/dbus-1.0/include"
      args << "-I#{dbus_opt}/include/dbus-1.0"
      args << "-L#{dbus_opt}/lib"
      args << "-ldbus-1"
      args << "-dbus-linked"
    end

    args << "-nomake" << "docs" if build.without? "docs"

    if MacOS.prefer_64_bit?
      args << "-arch" << "x86_64"
    else
      args << "-arch" << "x86"
    end
    
    # Patch macdeployqt so it finds the plugin path
    inreplace "tools/macdeployqt/macdeployqt/main.cpp", '"/Developer/Applications/Qt/plugins"', "\"#{HOMEBREW_PREFIX}/lib/qt4/plugins\""
    inreplace "tools/macdeployqt/macdeployqt/main.cpp", 'deploymentInfo.qtPath + "/plugins"', "\"#{HOMEBREW_PREFIX}/lib/qt4/plugins\""

    system "./configure", *args
    system "make"
    ENV.deparallelize
    system "make", "install"
    
    # Delete qmake, as we'll be rebuilding it
    system "rm", "bin/qmake"
    system "rm", "#{bin}/qmake"
    system "make", "clean"
    
    # Patch the configure script so the built qmake can find Webkit if installed
    inreplace "configure", '=$QT_INSTALL_PREFIX"`', "=#{HOMEBREW_PREFIX}\"`"
    inreplace "configure", '=$QT_INSTALL_DOCS"`', "=#{HOMEBREW_PREFIX}/doc\"`"
    inreplace "configure", '=$QT_INSTALL_HEADERS"`', "=#{HOMEBREW_PREFIX}/include\"`"
    inreplace "configure", '=$QT_INSTALL_LIBS"`', "=#{HOMEBREW_PREFIX}/lib\"`"
    inreplace "configure", '=$QT_INSTALL_BINS"`', "=#{HOMEBREW_PREFIX}/bin\"`"
    inreplace "configure", '=$QT_INSTALL_PLUGINS"`', "=#{HOMEBREW_PREFIX}/lib/qt4/plugins\"`"
    inreplace "configure", '=$QT_INSTALL_IMPORTS"`', "=#{HOMEBREW_PREFIX}/lib/qt4/imports\"`"
    inreplace "configure", '=$QT_INSTALL_DATA"`', "=#{HOMEBREW_PREFIX}/etc/qt4\"`"
    inreplace "configure", '=$QT_INSTALL_SETTINGS"`', "=#{HOMEBREW_PREFIX}\"`"

    # Run ./configure again, to rebuild qmake
    system "./configure", *args
    bin.install "bin/qmake"

    # what are these anyway?
    (bin+"pixeltool.app").rmtree
    (bin+"qhelpconverter.app").rmtree

    # Some config scripts will only find Qt in a "Frameworks" folder
    frameworks.install_symlink Dir["#{lib}/*.framework"]

    # The pkg-config files installed suggest that headers can be found in the
    # `include` directory. Make this so by creating symlinks from `include` to
    # the Frameworks' Headers folders.
    Pathname.glob("#{lib}/*.framework/Headers") do |path|
      include.install_symlink path => path.parent.basename(".framework")
    end
    
    # Make `HOMEBREW_PREFIX/lib/qt4/plugins` an additional plug-in search path
    # for Qt Designer to support formulae that provide Qt Designer plug-ins.
    system "/usr/libexec/PlistBuddy",
            "-c", "Add :LSEnvironment:QT_PLUGIN_PATH string \"#{HOMEBREW_PREFIX}/lib/qt4/plugins\"",
           "#{bin}/Designer.app/Contents/Info.plist"

    Pathname.glob("#{bin}/*.app") { |app| mv app, prefix }
  end

  def caveats; <<~EOS
    We agreed to the Qt opensource license for you.
    If this is unacceptable you should uninstall.

    Phonon is not supported on macOS Sierra or with Xcode 8.
    
    WebKit is no longer included for security reasons. If you absolutely
    need it, it can be installed with `brew install qt-webkit@2.3`.
    EOS
  end

  test do
    Encoding.default_external = "UTF-8" unless RUBY_VERSION.start_with? "1."
    resource("test-project").stage testpath
    system bin/"qmake"
    system "make"
    assert_match(/GitHub/, pipe_output(testpath/"qtnetwork-test 2>&1", nil, 0))
  end
  
  bottle do
    root_url "https://dl.bintray.com/cartr/autobottle-qt4"
    sha256 "a36630189041fd5938fba4590927756877cf6534612588cbb7952994490a38b3" => :high_sierra
    sha256 "e0079a2e7d06ef88eadfffb4c96eaa1e08697f5792df42d973b5e52058d8b15d" => :sierra
    sha256 "5515a907c5de5561176112baa4333161964d9bb40d2ed1f9c5e49257f5a0b7ac" => :el_capitan
    sha256 "d62234507074af1305d2b29bb0b8eecc0c4e8f03c02b505a37cee1d5f3cfc0a2" => :yosemite
  end
end
