# frozen_string_literal: true
require "mechanize"
require "date"
require "csv"
require "spreadsheet"
ENV["SSL_CERT_FILE"] = "./cacert.pem"

class Crawler
  INPUT_CSV_NAME = "JPTag_input.csv"
  OUTPUT_CSV_NAME = "JPTag_info_#{Date.today.strftime("%Y_%m_%d")}.csv"
  OUTPUT_EXCEL = "JPTag_info_#{Date.today.strftime("%Y_%m_%d")}.xls"

  def initialize
    @agent = Mechanize.new
    @ids = read_ids_from_csv(INPUT_CSV_NAME)
    @logger = Logger.new("logfile.log", 10, 1024000)
    write_header_to_csv
  end

  def crawl
    begin
      start_time = Time.now
      agree_page = @agent.get("https://www.id.nlbc.go.jp/CattleSearch/search/agreement.action")
      agree_form = agree_page.form("agreement")
      @input_page = @agent.submit(agree_form, agree_form.buttons.first)
      @ids.each { |id| crawl_one(id) }
      convert_csv_to_xls(OUTPUT_CSV_NAME)
      end_time = Time.now
      @logger.info("Total time: #{end_time - start_time}s")
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
      if tags.empty? || tags.size < 20
        @logger.info("ID #{id}'s tags: #{tags.map{ |tag| tag_to_text(tag) }.join(",")}")
        return write_unknown(id)
      end

      import_date = tag_to_text(tags[7]).gsub(".", "-")
      dob = tag_to_text(tags[11]).gsub(".", "-")

      tags[19..-1].each_slice(6) do |row|
        transfer = tag_to_text(row[1])
        transfer_date = tag_to_text(row[2]).gsub(".", "-")
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
      retries = 0
      begin
        puts "Crawling id #{id}..."
        input_form = @input_page.form("frmSearch")
        input_form.txtIDNO = "#{id}"
        @input_page = result_page = @agent.submit(input_form, input_form.buttons.first)
        tags = result_page.search(".resultTable") || []
        process_tags(id, tags)
      rescue => e
        if (retries += 1) <= 3
          puts "Error #{e}. Retry."
          retry
        else
          puts "Error #{e}. Give up."
          @logger.error("ID #{id}: Retried 3 times, still failed with error #{e}.")
        end
      end
    end

    def write_header_to_csv
      bom = %w(EF BB BF).map { |e| e.hex.chr }.join
      csv_file = CSV.generate(bom) do |csv|
        csv << ["Tag", "Import date", "DOB", "Transfer", "Transfer Date", "Prefecture", "City", "Location"]
      end
      File.open(OUTPUT_CSV_NAME,"w") do |file|
        file.write(csv_file)
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

    def convert_csv_to_xls(csv_file)
      Spreadsheet.client_encoding = "UTF-8"
      book = Spreadsheet::Workbook.new
      sheet1 = book.create_worksheet

      header_format = Spreadsheet::Format.new(
        weight: :bold
      )
      sheet1.row(0).default_format = header_format

      CSV.open(OUTPUT_CSV_NAME, "r") do |csv|
        csv.each_with_index do |row, i|
          # Convert "Import date", "DOB", "Transfer Date" to Date type
          [1, 2, 4].each do |col|
            row[col] = Date.parse(row[col]) rescue row[col]
          end
          sheet1.row(i).replace(row)
          date_format = Spreadsheet::Format.new(number_format: "DD/MM/YYYY")
          sheet1.row(i).set_format(1, date_format)
          sheet1.row(i).set_format(2, date_format)
          sheet1.row(i).set_format(4, date_format)
        end
      end
      book.write(OUTPUT_EXCEL)
    end
end


crawler = Crawler.new
puts "Start crawling..."
crawler.crawl
puts "Finished crawling"
