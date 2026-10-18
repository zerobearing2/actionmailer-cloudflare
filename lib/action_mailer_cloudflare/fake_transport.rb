class ActionMailerCloudflare::FakeTransport
  ACCEPTED = { success: true, errors: [], messages: [], result: { delivered: [ "a@example.com" ], permanent_bounces: [], queued: [] } }
  Request = Struct.new(:url, :headers, :body, keyword_init: true) do
    def json = JSON.parse(body)
  end

  attr_reader :sent

  def initialize
    @sent = []
    @answer = -> { ActionMailerCloudflare::Response.new(status: 200, body: JSON.generate(ACCEPTED)) }
  end

  def answer(status:, json: nil, body: nil)
    @answer = -> { ActionMailerCloudflare::Response.new(status:, body: json ? JSON.generate(json) : body.to_s) }
    self
  end

  def fail_with(error)
    @answer = -> { raise error }
    self
  end

  def post(url, headers:, body:)
    @sent << Request.new(url:, headers:, body:)
    @answer.call
  end
end
