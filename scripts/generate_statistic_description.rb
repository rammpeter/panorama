require 'nokogiri'
require 'open-uri'

# The Oracle docu page 'Statistics Descriptions' contains a table with statistics descriptions
url = 'https://docs.oracle.com/en/database/oracle/oracle-database/23/refrn/statistics-descriptions-2.html#GUID-2FBC1B7E-9123-41DD-8178-96176260A639'
html_content = URI.open(url)

# Parse the HTML content
doc = Nokogiri::HTML(html_content)

table = doc.css('table')

# Extract the table rows
rows = table.css('tr')

# Process each row
rows.each do |row|
  # Extract columns from each row
  columns = row.css('td')
  unless columns.empty?
    # Replace line feed with multiple following spaces with a single space
    key = columns[0]&.text&.strip&.gsub(/\n\s{2,}/, ' ')&.gsub('"', '\\"')
    # Escape double quotes in description and replace line feed with multiple following spaces with a \n
    desc = columns[2]&.text&.strip&.gsub('"', '\\"')&.gsub(/\n\s{2,}/, '\n')
    puts "\"#{key}\" => \"#{desc}\","
  end
end