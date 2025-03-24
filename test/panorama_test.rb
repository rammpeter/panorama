require 'test_helper'

class Panorama::Test < ActiveSupport::TestCase
  test "truth" do
    assert_kind_of Module, Panorama
  end

  GERMAN_SPECIAL_CHARS = "äöüßÄÖÜ"

    # Check if all .rb files in the whole project have either only ASCII characters or "# encoding: utf-8" set
  test "check_for_charset" do
    # Check if all .rb files in the whole project have either only ASCII characters or "# encoding: utf-8" set
    Dir.glob('**/*.rb').each do |file|
      next if file =~ /^vendor/
      next if File.read(file) =~ /# encoding: utf-8/
      line_number = 0
      File.foreach(file) do |line, index|
        line_number += 1
        next if line.ascii_only?
        charpos = 0
        line.each_char do |char|
          charpos += 1
          next if char.ascii_only? || GERMAN_SPECIAL_CHARS.include?(char)
          raise "File '#{file}' contains non-ASCII character '#{char}' with code #{char.ord} in line #{line_number} at position #{charpos} .\nPlease add '# encoding: utf-8' to the file or fix the following line content:\n#{line}"
        end
      end
    end
  end
end

