require File.dirname(__FILE__) + '/../spec_helper'

describe "Eye::Dsl checks" do

  it "ok checks" do
    conf = <<-E
      Eye.application("bla") do
        process("1") do
          pid_file "1.pid"

          checks :memory, :below => 100.megabytes, :every => 10.seconds
          checks :cpu,    :below => 100, :every => 20.seconds
        end
      end
    E
    Eye::Dsl.parse_apps(conf).should == {"bla" => {:name => "bla", :groups=>{"__default__"=>{:name => "__default__", :application => "bla", :processes=>{"1"=>{:pid_file=>"1.pid", :checks=>{:memory=>{:below=>104857600, :every=>10, :type=>:memory}, :cpu=>{:below=>100, :every=>20, :type=>:cpu}}, :application=>"bla", :group=>"__default__", :name=>"1"}}}}}}
  end

  it "inherit checks" do
    conf = <<-E
      Eye.application("bla") do
        checks :memory, :below => 100.megabytes, :every => 10.seconds

        process("1") do
          pid_file "1.pid"

          checks :memory, :below => 90.megabytes, :every => 5.seconds
          checks :cpu,    :below => 100, :every => 20.seconds
        end

        process("2") do
          pid_file "2.pid"
        end
      end
    E
    Eye::Dsl.parse_apps(conf).should == {"bla" => {:name => "bla", :checks=>{:memory=>{:below=>104857600, :every=>10, :type=>:memory}}, :groups=>{"__default__"=>{:name => "__default__", :application => "bla", :checks=>{:memory=>{:below=>104857600, :every=>10, :type=>:memory}}, :processes=>{"1"=>{:checks=>{:memory=>{:below=>94371840, :every=>5, :type=>:memory}, :cpu=>{:below=>100, :every=>20, :type=>:cpu}}, :pid_file=>"1.pid", :application=>"bla", :group=>"__default__", :name=>"1"}, "2"=>{:checks=>{:memory=>{:below=>104857600, :every=>10, :type=>:memory}}, :pid_file=>"2.pid", :application=>"bla", :group=>"__default__", :name=>"2"}}}}}}
  end

  it "checks in monitor_children" do
    conf = <<-E
      Eye.application("bla") do
        process("1") do
          pid_file "1.pid"
          monitor_children{
            checks :cpu,    :below => 100, :every => 20.seconds
          }
        end
      end
    E
    Eye::Dsl.parse_apps(conf).should == {"bla" => {:name => "bla", :groups=>{"__default__"=>{:name => "__default__", :application => "bla", :processes=>{"1"=>{:pid_file=>"1.pid", :monitor_children=>{:checks=>{:cpu=>{:below=>100, :every=>20, :type=>:cpu}}}, :application=>"bla", :group=>"__default__", :name=>"1"}}}}}}
  end

  it "child should not inherit checks" do
    conf = <<-E
      Eye.application("bla") do
        process("1") do
          pid_file "1.pid"
          checks :cpu,    :below => 100, :every => 20.seconds
          monitor_children{
          }
        end
      end
    E
    Eye::Dsl.parse_apps(conf).should == {"bla" => {:name=>"bla", :groups=>{"__default__"=>{:name=>"__default__", :application=>"bla", :processes=>{"1"=>{:name=>"1", :application=>"bla", :group=>"__default__", :pid_file=>"1.pid", :checks=>{:cpu=>{:below=>100, :every=>20, :type=>:cpu}}, :monitor_children=>{}}}}}}}
  end

  it "no valid checks" do
    conf = <<-E
      Eye.application("bla") do
        process("1") do
          pid_file "1.pid"
          checks :cpu,    :below => {1 => 2}, :every => 20.seconds
        end
      end
    E
    expect{Eye::Dsl.parse_apps(conf)}.to raise_error(Eye::Dsl::Validation::Error)
  end

  it "ok trigger" do
    conf = <<-E
      Eye.application("bla") do
        process("1") do
          pid_file "1.pid"

          triggers :flapping, :times => 2, :within => 15.seconds
        end
      end
    E
    Eye::Dsl.parse_apps(conf).should == {"bla" => {:name => "bla", :groups=>{"__default__"=>{:name => "__default__", :application => "bla", :processes=>{"1"=>{:pid_file=>"1.pid", :triggers=>{:flapping=>{:times=>2, :within=>15, :type=>:flapping}}, :application=>"bla", :group=>"__default__", :name=>"1"}}}}}}
  end

  it "no valid trigger" do
    conf = <<-E
      Eye.application("bla") do
        process("1") do
          pid_file "1.pid"
          triggers :flapping, :times => 2, :within => "bla"
        end
      end
    E
    expect{Eye::Dsl.parse_apps(conf)}.to raise_error(Eye::Dsl::Validation::Error)
  end

  it "nochecks to remove inherit checks" do
    conf = <<-E
      Eye.application("bla") do
        checks :memory, :below => 100.megabytes, :every => 10.seconds

        process("1") do
          pid_file "1.pid"
          nochecks :memory
        end

        process("2") do
          pid_file "2.pid"
        end
      end
    E
    Eye::Dsl.parse_apps(conf).should == {
      "bla" => {:name => "bla", :checks=>{:memory=>{:below=>104857600, :every=>10, :type=>:memory}},
      :groups=>{
        "__default__"=>{:name => "__default__", :application => "bla",
          :checks=>{:memory=>{:below=>104857600, :every=>10, :type=>:memory}},
          :processes=>{
            "1"=>{:checks=>{}, :pid_file=>"1.pid", :application=>"bla", :group=>"__default__", :name=>"1"},
            "2"=>{:checks=>{:memory=>{:below=>104857600, :every=>10, :type=>:memory}}, :pid_file=>"2.pid", :application=>"bla", :group=>"__default__", :name=>"2"}}}}}}
  end

  it "empty nocheck do nothing and inherit" do
    conf = <<-E
      Eye.application("bla") do
        checks :memory, :below => 100.megabytes, :every => 10.seconds
        nochecks :cpu
        notriggers :flapping

        group :blagr do
          process("1") do
            pid_file "1.pid"
            nochecks :cpu
            nochecks :memory
          end
        end

        process("2") do
          pid_file "2.pid"
        end
      end
    E
    Eye::Dsl.parse_apps(conf).should == {
      "bla" => {:name => "bla",
        :checks=>{:memory=>{:below=>104857600, :every=>10, :type=>:memory}},
        :groups=>{
          "blagr" => {:name=>"blagr", :checks=>{:memory=>{:below=>104857600, :every=>10, :type=>:memory}}, :application=>"bla",
            :processes => {"1"=>{:checks=>{}, :pid_file=>"1.pid", :application=>"bla", :group=>"blagr", :name=>"1"}}},
          "__default__"=>{:name =>
            "__default__", :application => "bla",
            :checks=>{:memory=>{:below=>104857600, :every=>10, :type=>:memory}}, :processes=>{
              "2"=>{:checks=>{:memory=>{:below=>104857600, :every=>10, :type=>:memory}}, :pid_file=>"2.pid", :application=>"bla", :group=>"__default__", :name=>"2"}}}}}}
  end

  it "process with unknown checker type" do
    conf = <<-E
      Eye.application("bla") do |app|
        app.process("1") do
          pid_file "2.pid"

          checks :bla, :a => 1
        end
      end
    E
    expect{Eye::Dsl.parse_apps(conf)}.to raise_error(Eye::Dsl::Error)
  end

  it "process with unknown triggers type" do
    conf = <<-E
      Eye.application("bla") do |app|
        app.process("1") do
          pid_file "2.pid"

          triggers :bla, :a => 1
        end
      end
    E
    expect{Eye::Dsl.parse_apps(conf)}.to raise_error(Eye::Dsl::Error)
  end

  it "check with Proc" do
    conf = <<-E
      Eye.application("bla") do
        process("1") do
          pid_file "1.pid"

          checks :socket, :addr => "unix:/tmp/1", :expect_data => Proc.new{|data| data == 1}
        end

        process("3") do
          pid_file "3.pid"

          checks :socket, :addr => "unix:/tmp/3", :expect_data => /regexp/
        end

        process("2") do
          pid_file "2.pid"

          checks :socket, :addr => "unix:/tmp/2", :expect_data => Proc.new{|data| data == 1}
        end

      end
    E
    res = Eye::Dsl.parse_apps(conf)
    proc = res['bla'][:groups]['__default__'][:processes]['1'][:checks][:socket][:expect_data]
    proc[0].should == false
    proc[1].should == true

    proc = res['bla'][:groups]['__default__'][:processes]['2'][:checks][:socket][:expect_data]
    proc[0].should == false
    proc[1].should == true
  end

  it "define custom check" do
    conf = <<-E
      class Cpu2 < Eye::Checker::Custom
        # checks :cpu2, :every => 3.seconds, :below => 80, :times => [3,5]
        param :below, [Fixnum, Float], true

        def check_name
          @check_name ||= "cpu2(\#{human_value(below)})"
        end

        def get_value
          `top -b -p \#{@pid} -n 1 | grep '\#{@pid}'| awk '{print $9}'`.chomp.to_i
        end

        def human_value(value)
          "\#{value}%"
        end

        def good?(value)
          value < below
        end
      end

      Eye.application("bla") do
        process("1") do
          pid_file "1.pid"

          checks :cpu2, :times => 2, :below => 80, :every => 30
        end
      end
    E

    res = Eye::Dsl.parse_apps(conf)
    res.should == {"bla"=>{:name=>"bla", :groups=>{
      "__default__"=>{:name=>"__default__", :application=>"bla", :processes=>{
        "1"=>{:name=>"1", :application=>"bla", :group=>"__default__", :pid_file=>"1.pid",
          :checks=>{:cpu2=>{:times=>2, :below=>80, :every=>30, :type=>:cpu2}}}}}}}}
  end

  it "define custom check in Checker scope" do
    conf = <<-E
      class Eye::Checker::Khg < Eye::Checker::Custom
      end

      Eye.application("bla") do
        process("1") do
          pid_file "1.pid"
          checks :khg, :times => 2, :every => 30
        end
      end
    E

    Eye::Dsl.parse_apps(conf)
  end

  it "define custom trigger" do
    conf = <<-E
      class DeleteFile < Eye::Trigger::Custom
        param :file, [String], true

        def check(transition)
          File.delete(file) if transition.to_name == :down
        end
      end

      Eye.application("bla") do
        process("1") do
          pid_file "1.pid"

          trigger :delete_file, :file => "/tmp/111111"
        end
      end
    E

    res = Eye::Dsl.parse_apps(conf)
    res.should == {"bla" => {:name=>"bla", :groups=>{
      "__default__"=>{:name=>"__default__", :application=>"bla", :processes=>{
        "1"=>{:name=>"1", :application=>"bla", :group=>"__default__", :pid_file=>"1.pid",
          :triggers=>{:delete_file=>{:file=>"/tmp/111111", :type=>:delete_file}}}}}}}}
  end

  describe "two checks with the same type" do

    it "two checks with the same type" do
      conf = <<-E
        Eye.application("bla") do
          process("1") do
            pid_file "1.pid"

            checks :memory, :below => 100.megabytes, :every => 10.seconds
            checks :memory2, :below => 100, :every => 20.seconds
            checks :memory_3, :below => 100, :every => 20.seconds
          end
        end
      E
      Eye::Dsl.parse_apps(conf).should == {
        "bla" => {:name=>"bla", :groups=>{
          "__default__"=>{:name=>"__default__", :application=>"bla", :processes=>{
            "1"=>{:name=>"1", :application=>"bla", :group=>"__default__", :pid_file=>"1.pid",
              :checks=>{
                :memory=>{:below=>104857600, :every=>10, :type=>:memory},
                :memory2=>{:below=>100, :every=>20, :type=>:memory},
                :memory_3=>{:below=>100, :every=>20, :type=>:memory}}}}}}}}
    end

    it "with nochecks" do
      conf = <<-E
        Eye.application("bla") do
          checks :memory, :below => 100

          process("1") do
            pid_file "1.pid"

            nochecks :memory
            checks :memory2, :below => 100, :every => 20.seconds
          end
        end
      E
      Eye::Dsl.parse_apps(conf).should == {
        "bla" => {:name=>"bla", :checks=>{:memory=>{:below=>100, :type=>:memory}}, :groups=>{
          "__default__"=>{:name=>"__default__",
            :checks=>{
              :memory=>{:below=>100, :type=>:memory}}, :application=>"bla", :processes=>{
                "1"=>{:name=>"1", :checks=>{
                  :memory2=>{:below=>100, :every=>20, :type=>:memory}},
                  :application=>"bla", :group=>"__default__", :pid_file=>"1.pid"}}}}}}
    end

    it "do not cross if there custom checker already" do
      conf = <<-E
        class Cpu2 < Eye::Checker::Custom
          param :below, [Fixnum, Float], true
        end

        Eye.application("bla") do
          process("1") do
            pid_file "1.pid"
            checks :cpu, :below => 100.megabytes, :every => 10.seconds
            checks :cpu2, :below => 100, :every => 20.seconds
            checks :cpu3, :below => 100, :every => 20.seconds
          end
        end
      E
      Eye::Dsl.parse_apps(conf).should == {
        "bla" => {:name=>"bla", :groups=>{
          "__default__"=>{:name=>"__default__", :application=>"bla", :processes=>{
            "1"=>{:name=>"1", :application=>"bla", :group=>"__default__", :pid_file=>"1.pid",
              :checks=>{
                :cpu=>{:below=>104857600, :every=>10, :type=>:cpu},
                :cpu2=>{:below=>100, :every=>20, :type=>:cpu2},
                :cpu3=>{:below=>100, :every=>20, :type=>:cpu}}}}}}}}
    end

    it "errored cases" do
      conf = <<-E
        Eye.application("bla") do
          checks :memory_bla, :below => 100.megabytes, :every => 10.seconds
        end
      E
      expect{ Eye::Dsl.parse_apps(conf) }.to raise_error(Eye::Dsl::Error)

      conf = <<-E
        Eye.application("bla") do
          checks 'memory-4', :below => 100.megabytes, :every => 10.seconds
        end
      E
      expect{ Eye::Dsl.parse_apps(conf) }.to raise_error(Eye::Dsl::Error)
    end

  end

  describe "multiple triggers" do
    it "two checks with the same type" do
      conf = <<-E
        Eye.application("bla") do
          process("1") do
            pid_file "1.pid"

            trigger :state, :from => :a
            trigger :state2, :to => :b
            trigger :state_3, :event => :c
          end
        end
      E
      Eye::Dsl.parse_apps(conf).should == {
        "bla" => {:name=>"bla", :groups=>{
          "__default__"=>{:name=>"__default__", :application=>"bla", :processes=>{
            "1"=>{:name=>"1", :application=>"bla", :group=>"__default__", :pid_file=>"1.pid", :triggers=>{
              :state=>{:from=>:a, :type=>:state},
              :state2=>{:to=>:b, :type=>:state},
              :state_3=>{:event=>:c, :type=>:state}}}}}}}}
    end

    it "with notriggers" do
      conf = <<-E
        Eye.application("bla") do
          trigger :state

          process("1") do
            pid_file "1.pid"

            notrigger :state
            trigger :state2, :to => :up
          end
        end
      E
      Eye::Dsl.parse_apps(conf).should == {
        "bla" => {:name=>"bla", :triggers=>{:state=>{:type=>:state}}, :groups=>{
          "__default__"=>{:name=>"__default__",
            :triggers=>{:state=>{:type=>:state}}, :application=>"bla", :processes=>{
              "1"=>{:name=>"1", :triggers=>{:state2=>{:to=>:up, :type=>:state}},
              :application=>"bla", :group=>"__default__", :pid_file=>"1.pid"}}}}}}
    end

    it "errored cases" do
      conf = <<-E
        Eye.application("bla") do
          trigger :memory_bla, :below => 100.megabytes, :every => 10.seconds
        end
      E
      expect{ Eye::Dsl.parse_apps(conf) }.to raise_error(Eye::Dsl::Error)

      conf = <<-E
        Eye.application("bla") do
          trigger 'memory-4', :below => 100.megabytes, :every => 10.seconds
        end
      E
      expect{ Eye::Dsl.parse_apps(conf) }.to raise_error(Eye::Dsl::Error)
    end

  end

end
