# frozen_string_literal: true
require "mechanize"
require "date"
require "csv"
ENV["SSL_CERT_FILE"] = "./cacert.pem"

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
      start_time = Time.now
      @ids.each { |id| crawl_one(id) }
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
        @logger.info("ID #{id}'s tags: #{tags}")
        return write_unknown(id)
      end

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
      puts "Crawling id #{id}..."
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
end


crawler = Crawler.new
puts "Start crawling..."
crawler.crawl
puts "Finished crawling"
