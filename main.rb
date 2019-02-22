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
    @logger = Logger.new("logfile.log", 10, 1024000)
    write_header_to_csv
  end

  def crawl
    begin
      @ids.each { |id| crawl_one(id) }
    rescue => e
      @logger.error(e.to_s)
      @logger.error(e.backtrace.join("\n"))
    end
  end

  private
    def read_ids_from_csv(file_name)
      CSV.read(file_name).flatten
    end

    def process_tags(id, tags)
      tag_id = id
      return write_unknown(id) if tags.empty?

      import_date = tag_to_text(tags[7])
      dob = tag_to_text(tags[11])

      tags[19..-1].each_slice(6) do |row|
        transfer = tag_to_text(row[1])
        transfer_date = tag_to_text(row[2])
        prefecture = tag_to_text(row[3])
        city = tag_to_text(row[4])
        location = tag_to_text(row[5])
        write_to_csv(tag_id, import_date, dob,
                     transfer, transfer_date,
                     prefecture, city, location)
      end
    end

    def tag_to_text(tag)
      tag.text.strip rescue "Unknown"
    end

    def crawl_one(id)
      agree_page = @agent.get("https://www.id.nlbc.go.jp/CattleSearch/search/agreement.action")
      agree_form = agree_page.form("agreement")
      input_page = @agent.submit(agree_form, agree_form.buttons.first)
      input_form = input_page.form("frmSearch")
      input_form.txtIDNO = "#{id}"
      result_page = @agent.submit(input_form, input_form.buttons.first)
      tags = result_page.search(".resultTable") || []
      process_tags(id, tags)
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

    def write_unknown(id)
      CSV.open(OUTPUT_CSV_NAME, "a") do |csv|
        csv << Array.new(7, "Unknown").unshift(id)
      end
    end
end

crawler = Crawler.new
crawler.crawl
