#
#  Be sure to run `pod spec lint ZLFullTextSearch.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  #

  s.name         = "ZLFullTextSearch"
  s.version      = "0.3.0"
  s.summary      = "An objective-c library for indexing, searching and ranking results."

  s.description  = <<-DESC
                   A longer description of ZLFullTextSearch in Markdown format.

                   This library manages indexing, searching and ranking results.
                   DESC

    s.homepage     = "https://github.com/zackliston/ZLFullTextSearch"

    s.license      = { :type => "MIT", :file => "LICENSE" }

    s.author             = { "Zack Liston" => "zackmliston@gmail.com" }
  # Or just: s.author    = "Zack Liston"
  # s.authors            = { "Zack Liston" => "zackmliston@gmail.com" }
    s.social_media_url   = "http://twitter.com/zackmliston"


    s.platform     = :ios, "7.0"

    s.source       = { :git => "https://github.com/zackliston/ZLFullTextSearch.git", :tag => "0.3.0" }

    s.source_files  = "Source", "Source/.{h,m,c}"
    s.requires_arc = true
    s.dependencies = {
        'ZLTaskManager' => '0.1.1',
        'FMDB/FTS' => '2.4'
    }


end
