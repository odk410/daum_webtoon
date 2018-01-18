require 'sinatra'
require 'sinatra/reloader'
require 'httparty'
require 'json'
require 'data_mapper'

set :bind, '0.0.0.0'

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/webtoon.db")

class Webtoon
  include DataMapper::Resource
  property :id, Serial
  property :name, String
  property :decs, String
  property :score, Float  # String으로 받으면 이걸 이용한 다른 것을 하기에 제한된다.
  property :img_url, String
  property :url, String
  property :created_at, DateTime
end

DataMapper.finalize

Webtoon.auto_upgrade!

get '/' do
  erb :index
end

get '/scrap' do
  #월 ~ 금요일 까지의 웹툰을 차례차례 긁어 온다.
  # 1. 월요일의 웹툰을 긁어온다.
  # 2. 화~일 순서로 요일별 웹툰을 긁어 온다.
  days = ["mon", 'tue', "wed", "thu", "fri", "sat", "sun"]
  @webtoon = Array.new
  days.each do |day|
    url = "http://webtoon.daum.net/data/pc/webtoon/list_serialized/#{day}"
    response = HTTParty.get(url)
    doc = JSON.parse(response.body)
    @webtoons = Array.new
    doc["data"].each do |webtoon|
      toon = {
        name: webtoon["title"],
        desc: webtoon["introduction"],
        score: webtoon["averageScore"], #반올림 소수점 2자리에서
        img_url: webtoon["appThumbnailImage"]["url"],
        url: "http://webtoon.daum.net/webtoon/view/#{webtoon['nickname']}"
      }
      @webtoons << toon
    end
  end

  @webtoon.each do |webtoon|
      Webtoon.create(
        name: webtoon[:name],
        desc: webtoon[:desc],
        score: webtoon[:score].to_f,
        img_url: webtoon[:img_url],
        url: webtoon[:url]
      )
  end

end

get '/week/:day' do
  day = params[:day]

  # 1. url을 만든다.
  # 다음 웹툰에서 원래 URL = http://webtoon.daum.net/data/pc/webtoon/list_serialized/fri?timeStamp=1513559736743이다.
  # http://webtoon.daum.net/data/pc/webtoon/list_serialized/부분까지는 변하지 않는다.
  # 뒷 부분은 우리가 만들어 주어야 한다. 아래 Time 변수는 timeStamp를 의미한다. 1970년부터 현재까지의 초이다.
  # 요일은 week에 저장해준다.
  url = "http://webtoon.daum.net/data/pc/webtoon/list_serialized/#{day}"

  # 2. 해당 url에 요청을 보내고 데이터를 받는다.
  response = HTTParty.get(url)

  # 3. JSON형식으로 날아온 데이터를 Hash형식으로 바꾼다.
  doc = JSON.parse(response.body)

  # 4. key를 이용해서 원하는 데이터만 수집한다.
  # 원하는 데이터 : 제목, 이미지, 웹툰 링크, 소개, 평점
  # 평점 : averageScore
  # 제목 : title
  # 소개 : introduction
  # 이미지 : appThumbnailImage["url"]
  # 링크 : "http://webtoon.daum.net/webtoon/view/#{nickname}"
  @webtoons = Array.new
  doc["data"].each do |webtoon|
    toon = {
      name: webtoon["title"],
      desc: webtoon["introduction"],
      score: webtoon["averageScore"], #반올림 소수점 2자리에서
      img_url: webtoon["appThumbnailImage"]["url"],
      url: "http://webtoon.daum.net/webtoon/view/#{webtoon['nickname']}"
    }

    @webtoons << toon

  end

  erb :day
end

get '/today' do
  # 1. url을 만든다.
  # 다음 웹툰에서 원래 URL = http://webtoon.daum.net/data/pc/webtoon/list_serialized/fri?timeStamp=1513559736743이다.
  # http://webtoon.daum.net/data/pc/webtoon/list_serialized/부분까지는 변하지 않는다.
  # 뒷 부분은 우리가 만들어 주어야 한다. 아래 Time 변수는 timeStamp를 의미한다. 1970년부터 현재까지의 초이다.
  # 요일은 week에 저장해준다.
  time = Time.now.to_i
  week = DateTime.now.strftime("%a").downcase
  url = "http://webtoon.daum.net/data/pc/webtoon/list_serialized/#{week}?timeStamp=#{time}"

  # 2. 해당 url에 요청을 보내고 데이터를 받는다.
  response = HTTParty.get(url)

  # 3. JSON형식으로 날아온 데이터를 Hash형식으로 바꾼다.
  doc = JSON.parse(response.body)

  # 4. key를 이용해서 원하는 데이터만 수집한다.
  # 원하는 데이터 : 제목, 이미지, 웹툰 링크, 소개, 평점
  # 평점 : averageScore
  # 제목 : title
  # 소개 : introduction
  # 이미지 : appThumbnailImage["url"]
  # 링크 : "http://webtoon.daum.net/webtoon/view/#{nickname}"
  @webtoons = Array.new
  doc["data"].each do |webtoon|
    toon = {
      name: webtoon["tile"],
      desc: webtoon["introduction"],
      score: webtoon["averageScore"], #반올림 소수점 2자리에서
      img_url: webtoon["appThumbnailImage"]["url"],
      url: "http://webtoon.daum.net/webtoon/view/#{webtoon['nickname']}"
    }

    @webtoons << toon

  end

  # 5. view에서 보여주기 위해 @webtoons라는 변수에 담는다.

  erb :webtoon_list
end
