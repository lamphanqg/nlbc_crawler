# frozen_string_literal: true

require "mechanize"
require "date"
require "csv"

class Crawler
  INPUT_CSV_NAME = "JPTag_input.csv"
  OUTPUT_CSV_NAME = "JPTag_info_#{Date.today.strftime("%Y_%m_%d")}.csv"
  def initialize
    @agent = Mechanize.new
    @ids = read_ids_from_csv(INPUT_CSV_NAME)
    write_header_to_csv
  end

  def crawl
    @ids.each { |id| crawl_one(id) }
  end

  private
    def read_ids_from_csv(file_name)
      CSV.read(file_name).flatten
    end

    def process_tags(tags)
      tag_id = tags[6].text.strip
      import_date = tags[7].text.strip
      dob = tags[11].text.strip

      tags[19..-1].each_slice(6) do |row|
        transfer = row[1].text.strip
        transfer_date = row[2].text.strip
        prefecture = row[3].text.strip
        city = row[4].text.strip
        location = row[5].text.strip
        write_to_csv(tag_id, import_date, dob,
                     transfer, transfer_date,
                     prefecture, city, location)
      end
    end

    def crawl_one(id)
      agree_page = @agent.get("https://www.id.nlbc.go.jp/CattleSearch/search/agreement.action")
      agree_form = agree_page.form("agreement")
      input_page = @agent.submit(agree_form, agree_form.buttons.first)
      input_form = input_page.form("frmSearch")
      input_form.txtIDNO = "#{id}"
      result_page = @agent.submit(input_form, input_form.buttons.first)
      tags = result_page.search(".resultTable")
      process_tags(tags)
    end

    def write_header_to_csv
      CSV.open(OUTPUT_CSV_NAME, "w") do |csv|
        csv << ["Tag", "Import date", "DOB", "Transfer", "Transfer Date", "Prefecture", "City", "Location"]
      end
    end

    def write_to_csv(tag_id, import_date, dob, transfer, transfer_date, prefecture, city, location)
      CSV.open(OUTPUT_CSV_NAME, "a") do |csv|
        csv << [tag_id, import_date, dob, transfer, transfer_date, prefecture, city, location]
      end
    end
end

crawler = Crawler.new
crawler.crawl
