require File.dirname(__FILE__) + '/../spec_helper'

def chhttp(cfg = {})
  Eye::Checker.create(nil, {:type => :http, :every => 5.seconds, 
        :times => 1, :url => "http://localhost:3000/", :kind => :success,
        :pattern => /OK/, :timeout => 2}.merge(cfg))
end

describe "Eye::Checker::Http" do

  after :each do
    FakeWeb.clean_registry
  end

  describe "get_value" do
    subject{ chhttp }

    it "initialize" do
      subject.instance_variable_get(:@kind).should == Net::HTTPSuccess
      subject.instance_variable_get(:@pattern).should == /OK/
      subject.instance_variable_get(:@open_timeout).should == 3
      subject.instance_variable_get(:@read_timeout).should == 2
    end

    it "without url" do
      chhttp(:url => nil).uri.should == URI.parse('http://127.0.0.1')
    end

    it "get_value" do
      FakeWeb.register_uri(:get, "http://localhost:3000/", :body => "Somebody OK")
      subject.get_value[:result].body.should == "Somebody OK"

      subject.human_value(subject.get_value).should == "200=0Kb"      
    end

    it "get_value exception" do      
      a = ""
      stub(subject).session{ a }
      stub(subject.session).start{ raise Timeout::Error, "timeout" }
      subject.get_value.should == {:exception => :timeout}

      subject.human_value(subject.get_value).should == "T-out"
    end

    it "get_value raised" do
      a = ""
      stub(subject).session{ a }
      stub(subject.session).start{ raise "something" }
      subject.get_value.should == {:exception => "something"}

      subject.human_value(subject.get_value).should == "Err"
    end

  end

  describe "good?" do
    subject{ chhttp }

    it "good" do
      FakeWeb.register_uri(:get, "http://localhost:3000/", :body => "Somebody OK")
      subject.check.should == true
    end

    it "good pattern is string" do
      subject = chhttp(:pattern => "OK")
      FakeWeb.register_uri(:get, "http://localhost:3000/", :body => "Somebody OK")
      subject.check.should == true
    end

    it "bad pattern" do
      FakeWeb.register_uri(:get, "http://localhost:3000/", :body => "Somebody bad")
      subject.check.should == false
    end

    it "bad pattern string" do
      subject = chhttp(:pattern => "OK")
      FakeWeb.register_uri(:get, "http://localhost:3000/", :body => "Somebody bad")
      subject.check.should == false
    end

    it "not 200" do
      FakeWeb.register_uri(:get, "http://localhost:3000/bla", :body => "Somebody OK", :status => [500, 'err'])
      subject.check.should == false
    end

    it "without patter its ok" do
      subject = chhttp(:pattern => nil)
      FakeWeb.register_uri(:get, "http://localhost:3000/", :body => "Somebody OK")
      subject.check.should == true
    end
  end

  describe "validates" do
    it "ok" do
      Eye::Checker.validate!({:type => :http, :every => 5.seconds, 
        :times => 1, :url => "http://localhost:3000/", :kind => :success,
        :pattern => /OK/, :timeout => 2})
    end

    it "without param url" do
      expect{ Eye::Checker.validate!({:type => :http, :every => 5.seconds, 
        :times => 1, :kind => :success,
        :pattern => /OK/, :timeout => 2}) }.to raise_error(Eye::Checker::Validation::Error)
    end

    it "bad param timeout" do
      expect{ Eye::Checker.validate!({:type => :http, :every => 5.seconds, 
        :times => 1, :kind => :success, :url => "http://localhost:3000/",
        :pattern => /OK/, :timeout => :fix}) }.to raise_error(Eye::Checker::Validation::Error)
    end
  end

end