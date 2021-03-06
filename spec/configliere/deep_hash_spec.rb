require 'spec_helper'

class AwesomeHash < DeepHash ; end

describe DeepHash do

  subject{ described_class.new({ :nested_1 => { :nested_2 => { :leaf_3 => "val3" }, :leaf_2 => ['arr'] }, :leaf_at_top => 'val1b' }) }

  let(:test_hash)    { { "str_key" => "strk_val", :sym_key => "symk_val" } }
  let(:subclass_hash){ AwesomeHash.new(test_hash) }

  context "#initialize" do
    it 'adopts a Hash when given' do
      deep_hash = described_class.new(test_hash)
      test_hash.each{ |k,v| deep_hash[k].should == v }
      deep_hash.keys.any?{ |key| key.is_a?(String) }.should be_false
    end

    it 'converts all pure Hash values into DeepHash if param is a Hash' do
      deep_hash = described_class.new :sym_key => test_hash
      deep_hash[:sym_key].should be_an_instance_of(described_class)
      deep_hash[:sym_key][:sym_key].should == "symk_val"
    end

    it 'does not convert Hash subclass values into DeepHashes' do
      deep_hash = described_class.new :sub => subclass_hash
      deep_hash[:sub].should be_an_instance_of(AwesomeHash)
    end

    it 'converts all value items if value is an Array' do
      deep_hash = described_class.new :arry => { :sym_key => [test_hash] }
      deep_hash[:arry].should be_an_instance_of(described_class)
      deep_hash[:arry][:sym_key].first[:sym_key].should == "symk_val"
    end

    it 'delegates to superclass constructor if param is not a Hash' do
      deep_hash = described_class.new("dash berlin")
      deep_hash["unexisting key"].should == "dash berlin"
    end
  end

  context "#update" do
    it 'converts all keys into symbols when param is a Hash' do
      deep_hash = described_class.new(test_hash)
      deep_hash.update("starry" => "night")
      deep_hash.keys.any?{|key| key.is_a?(String) }.should be_false
    end

    it 'converts all Hash values into DeepHashes if param is a Hash' do
      deep_hash = DeepHash.new :hash => test_hash
      deep_hash.update(:hash => { :sym_key => "is buggy in Ruby 1.8.6" })
      deep_hash[:hash].should be_an_instance_of(DeepHash)
    end
  end

  context '#[]=' do
    it 'symbolizes keys' do
      subject['leaf_at_top'] = :fedora
      subject['new']         = :unseen
      subject.should == {:nested_1 => {:nested_2 => {:leaf_3 => "val3"}, :leaf_2 => ['arr']}, :leaf_at_top => :fedora, :new => :unseen}
    end

    it 'deep-sets dotted vals, replacing values' do
      subject['moon.man'] = :cheesy
      subject[:moon][:man].should == :cheesy
    end

    it 'deep-sets dotted vals, creating new values' do
      subject['moon.cheese.type'] = :tilsit
      subject[:moon][:cheese][:type].should == :tilsit
    end

    it 'deep-sets dotted vals, auto-vivifying intermediate hashes' do
      subject['this.that.the_other'] = :fuhgeddaboudit
      subject[:this][:that][:the_other].should == :fuhgeddaboudit
    end

    it 'converts all Hash value into DeepHash' do
      deep_hash = described_class.new :hash => test_hash
      deep_hash[:hash] = { :sym_key => "is buggy in Ruby 1.8.6" }
      deep_hash[:hash].should be_an_instance_of(described_class)
    end

    it "only accepts #to_sym'bolizable things as keys" do
      expect{ subject[{ :a => :b }] = 'hi' }.to     raise_error(NoMethodError, /undefined method `to_sym'/)
      expect{ subject[Object.new] = 'hi'   }.to     raise_error(NoMethodError, /undefined method `to_sym'/)
      expect{ subject[:a] = 'hi'           }.to_not raise_error
    end
  end

  context '#[]' do
    let(:orig_hash){ { :hat => :cat, :basket => :lotion, :moon => { :man => :smiling, :cheese => {:type => :tilsit} } } }
    let(:subject  ){ Configliere::Param.new({ :hat => :cat, :basket => :lotion, :moon => { :man => :smiling, :cheese => {:type => :tilsit} } }) }

    it 'deep-gets dotted vals' do
      subject['moon.man'].should == :smiling
      subject['moon.cheese.type'].should == :tilsit
      subject['moon.cheese.smell'].should be_nil
      subject['moon.non.existent.interim.values'].should be_nil
      subject['moon.non'].should be_nil
      subject.should == orig_hash # shouldn't change from reading (specifically, shouldn't autovivify)
    end

    it 'indexing through a non-hash will raise an error', :if => (defined?(RUBY_ENGINE) && (RUBY_ENGINE !~ /rbx/)) do
      err_klass = (RUBY_VERSION >= "1.9.0") ? TypeError : NoMethodError
      expect{ subject['hat.dog'] }.to raise_error(err_klass, /Symbol/)
      subject.should == orig_hash # shouldn't change from reading (specifically, shouldn't autovivify)
    end

    it "only accepts #to_sym'bolizable things as keys" do
      expect{ subject[{ :a => :b }] }.to raise_error(NoMethodError, /undefined method `to_sym'/)
      expect{ subject[Object.new]   }.to raise_error(NoMethodError, /undefined method `to_sym'/)
    end
  end

  def arrays_should_be_equal arr1, arr2
    arr1.sort_by{|s| s.to_s }.should == arr2.sort_by{|s| s.to_s }
  end

  context "#to_hash" do
    it 'returns instance of Hash' do
      described_class.new(test_hash).to_hash.should be_an_instance_of(Hash)
    end

    it 'preserves keys' do
      deep_hash = described_class.new(test_hash)
      converted = deep_hash.to_hash
      arrays_should_be_equal deep_hash.keys, converted.keys
    end

    it 'preserves value' do
      deep_hash = described_class.new(test_hash)
      converted = deep_hash.to_hash
      arrays_should_be_equal deep_hash.values, converted.values
    end
  end

  context '#compact' do
    it 'removes nils but not empties or falsehoods' do
      described_class.new({ :a => nil }).compact.should == {}
      described_class.new({ :a => nil, :b => false, :c => {}, :d => "", :remains => true }).compact.should == { :b => false, :c => {}, :d => "", :remains => true }
    end

    it 'leaves original alone' do
      deep_hash = described_class.new({ :a => nil, :remains => true })
      deep_hash.compact.should == { :remains => true }
      deep_hash.should == { :a => nil, :remains => true }
    end
  end

  context '#compact!' do
    it 'removes nils but not empties or falsehoods' do
      described_class.new({ :a => nil }).compact!.should == {}
      described_class.new({ :a => nil, :b => false, :c => {}, :d => "", :remains => true }).compact!.should == { :b => false, :c => {}, :d => "", :remains => true }
    end

    it 'modifies in-place' do
      deep_hash = described_class.new({ :a => nil, :remains => true })
      deep_hash.compact!.should == { :remains => true }
      deep_hash.should == { :remains => true }
    end
  end

  context '#slice' do
    let(:subject){ Configliere::Param.new({ :a => 'x', :b => 'y', :c => 10 }) }

    it 'returns a new hash with only the given keys' do
      subject.slice(:a, :b).should == { :a => 'x', :b => 'y' }
      subject.should == { :a => 'x', :b => 'y', :c => 10 }
    end

    it 'with bang replaces the hash with only the given keys' do
      subject.slice!(:a, :b).should == { :c => 10 }
      subject.should == { :a => 'x', :b => 'y' }
    end

    it 'ignores an array key' do
      subject.slice([:a, :b], :c).should == { :c => 10 }
      subject.should == { :a => 'x', :b => 'y', :c => 10 }
    end

    it 'with bang ignores an array key' do
      subject.slice!([:a, :b], :c).should == { :a => 'x', :b => 'y' }
      subject.should == { :c => 10 }
    end

    it 'uses splatted keys individually' do
      subject.slice(*[:a, :b]).should == { :a => 'x', :b => 'y' }
      subject.should == { :a => 'x', :b => 'y', :c => 10 }
    end

    it 'with bank uses splatted keys individually' do
      subject.slice!(*[:a, :b]).should == { :c => 10 }
      subject.should == { :a => 'x', :b => 'y' }
    end
  end

  context '#extract' do
    let(:subject){ Configliere::Param.new({ :a => 'x', :b => 'y', :c => 10 }) }

    it 'replaces the hash with only the given keys' do
      subject.extract!(:a, :b).should == { :a => 'x', :b => 'y' }
      subject.should == { :c => 10 }
    end

    it 'leaves the hash empty if all keys are gone' do
      subject.extract!(:a, :b, :c).should == { :a => 'x', :b => 'y', :c => 10 }
      subject.should == {}
    end

    it 'gets values for all given keys even if missing' do
      subject.extract!(:bob, :c).should == { :bob => nil, :c => 10 }
      subject.should == { :a => 'x', :b => 'y' }
    end

    it 'is OK when empty' do
      described_class.new.slice!(:a, :b, :c).should == {}
    end

    it 'returns an instance of the same class' do
      subject.slice(:a).should be_a(described_class)
    end
  end

  context "#delete" do
    it 'converts Symbol key into String before deleting' do
      deep_hash = described_class.new(test_hash)
      deep_hash.delete(:sym_key)
      deep_hash.key?("hash").should be_false
    end

    it 'works with String keys as well' do
      deep_hash = described_class.new(test_hash)
      deep_hash.delete("str_key")
      deep_hash.key?("str_key").should be_false
    end
  end

  context "#fetch" do
    let(:subject){ Configliere::Param.new({ :no => :in_between }) }

    it 'converts key before fetching' do
      subject.fetch("no").should == :in_between
    end

    it 'returns alternative value if key lookup fails' do
      subject.fetch("flying", "screwdriver").should == "screwdriver"
    end
  end

  context "#values_at" do

    let(:subject  ){ Configliere::Param.new({ :no => :in_between, "str_key" => "strk_val", :sym_key => "symk_val"}) }

    it 'is indifferent to whether keys are strings or symbols' do
      subject.values_at("sym_key", :str_key, :no).should == ["symk_val", "strk_val", :in_between]
    end
  end

  it 'responds to #symbolize_keys, #symbolize_keys! and #stringify_keys but not #stringify_keys!' do
    described_class.new.should     respond_to(:symbolize_keys )
    described_class.new.should     respond_to(:symbolize_keys!)
    described_class.new.should     respond_to(:stringify_keys )
    described_class.new.should_not respond_to(:stringify_keys!)
  end

  context '#symbolize_keys' do
    it 'returns a dup of itself' do
      deep_hash = described_class.new(test_hash)
      deep_hash.symbolize_keys.should == deep_hash
    end
  end

  context '#symbolize_keys!' do
    it 'with bang returns the deep_hash itself' do
      deep_hash = described_class.new(test_hash)
      deep_hash.symbolize_keys!.object_id.should == deep_hash.object_id
    end
  end

  context '#stringify_keys' do
    it 'converts keys that are all symbols' do
      subject.stringify_keys.should ==
        { 'nested_1' => { :nested_2 => { :leaf_3 => "val3" }, :leaf_2 => ['arr'] }, 'leaf_at_top' => 'val1b' }
    end

    it 'returns a Hash, not a DeepHash' do
      subject.stringify_keys.class.should == Hash
      subject.stringify_keys.should_not be_a(DeepHash)
    end

    it 'only stringifies and hashifies the top level' do
      stringified = subject.stringify_keys
      stringified.should == { 'nested_1' => { :nested_2 => { :leaf_3 => "val3" }, :leaf_2 => ['arr'] }, 'leaf_at_top' => 'val1b' }
      stringified['nested_1'].should be_a(DeepHash)
    end
  end

  context '#assert_valid_keys' do
    let(:subject){ DeepHash.new({ :failure => "stuff", :funny => "business" }) }

    it 'is true and does not raise when valid' do
      subject.assert_valid_keys([ :failure, :funny ]).should be_nil
      subject.assert_valid_keys(:failure, :funny).should be_nil
    end

    it 'fails when invalid' do
      subject[:failore] = subject.delete(:failure)
      expect{ subject.assert_valid_keys([ :failure, :funny ]) }.to raise_error(ArgumentError, "Unknown key(s): failore")
      expect{ subject.assert_valid_keys(:failure, :funny)     }.to raise_error(ArgumentError, "Unknown key(s): failore")
    end
  end

  context "#merge" do
    it 'merges given Hash' do
      merged = subject.merge(:no => "in between")
      merged.should == { :nested_1 => { :nested_2 => { :leaf_3 => "val3" }, :leaf_2 => ['arr'] }, :leaf_at_top => 'val1b', :no => 'in between' }
    end

    it 'returns a new instance' do
      merged = subject.merge(:no => "in between")
      merged.should_not equal(subject)
    end

    it 'returns instance of DeepHash' do
      merged = subject.merge(:no => "in between")
      merged.should be_an_instance_of(DeepHash)
      merged[:no].should  == "in between"
      merged["no"].should == "in between"
    end

    it "converts all Hash values into DeepHashes"  do
      merged = subject.merge({ :nested_1 => { 'nested_2' => { :leaf_3_also => "val3a" } }, :other1 => { "other2" => "other_val2" }})
      merged[:nested_1].should be_an_instance_of(DeepHash)
      merged[:nested_1][:nested_2].should be_an_instance_of(DeepHash)
      merged[:other1].should be_an_instance_of(DeepHash)
    end

    it "converts string keys to symbol keys even if they occur deep in the given hash" do
      merged = subject.merge({   'a' => { 'b' => { 'c' => { :d => :e }}}})
      merged[:a].should     == { :b  => { :c  => { :d => :e }}}
      merged[:a].should_not == { 'b' => { 'c' => { :d => :e }}}
    end

    it "DOES merge values where given hash has nil value" do
      merged = subject.merge(:a => { :b => nil }, :c => nil, :leaf_3_also => nil)
      merged[:a][:b].should be_nil
      merged[:c].should be_nil
      merged[:leaf_3_also].should be_nil
    end

    it "replaces child hashes, and does not merge them"  do
      merged = subject.merge({ :nested_1 => { 'nested_2' => { :leaf_3_also => "val3a" } }, :other1 => { "other2" => "other_val2" }})
      merged.should       == { :nested_1 => { :nested_2  => { :leaf_3_also => "val3a" } }, :other1 => { :other2  => "other_val2" }, :leaf_at_top => 'val1b' }
    end
  end

  context "#merge!" do
    it 'merges given Hash' do
      subject.merge!(:no => "in between")
      subject.should == { :nested_1 => { :nested_2 => { :leaf_3 => "val3" }, :leaf_2 => ['arr'] }, :leaf_at_top => 'val1b', :no => 'in between' }
    end

    it 'returns a new instance' do
      subject.merge!(:no => "in between")
      subject.should equal(subject)
    end

    it 'returns instance of DeepHash' do
      subject.merge!(:no => "in between")
      subject.should be_an_instance_of(DeepHash)
      subject[:no].should  == "in between"
      subject["no"].should == "in between"
    end

    it "converts all Hash values into DeepHashes"  do
      subject.merge!({ :nested_1 => { 'nested_2' => { :leaf_3_also => "val3a" } }, :other1 => { "other2" => "other_val2" }})
      subject[:nested_1].should be_an_instance_of(DeepHash)
      subject[:nested_1][:nested_2].should be_an_instance_of(DeepHash)
      subject[:other1].should be_an_instance_of(DeepHash)
    end

    it "converts string keys to symbol keys even if they occur deep in the given hash" do
      subject.merge!({   'a' => { 'b' => { 'c' => { :d => :e }}}})
      subject[:a].should     == { :b  => { :c  => { :d => :e }}}
      subject[:a].should_not == { 'b' => { 'c' => { :d => :e }}}
    end

    it "DOES merge values where given hash has nil value" do
      subject.merge!(:a => { :b => nil }, :c => nil, :leaf_3_also => nil)
      subject[:a][:b].should be_nil
      subject[:c].should be_nil
      subject[:leaf_3_also].should be_nil
    end

    it "replaces child hashes, and does not merge them"  do
      subject.merge!({ :nested_1 => { 'nested_2' => { :leaf_3_also => "val3a" } }, :other1 => { "other2" => "other_val2" }})
      subject.should           == { :nested_1 => { :nested_2  => { :leaf_3_also => "val3a" } }, :other1 => { :other2  => "other_val2" }, :leaf_at_top => 'val1b' }
      subject.should_not       == { :nested_1 => { 'nested_2' => { :leaf_3_also => "val3a" } }, :other1 => { "other2" => "other_val2" }, :leaf_at_top => 'val1b' }
    end
  end

  context "#reverse_merge" do
    it 'merges given Hash' do
      subject.reverse_merge!(:no => "in between", :leaf_at_top => 'NOT_USED')
      subject.should == { :nested_1 => { :nested_2 => { :leaf_3 => "val3" }, :leaf_2 => ['arr'] }, :leaf_at_top => 'val1b', :no => 'in between' }
    end

    it 'returns a new instance' do
      subject.reverse_merge!(:no => "in between")
      subject.should equal(subject)
    end

    it 'returns instance of DeepHash' do
      subject.reverse_merge!(:no => "in between")
      subject.should be_an_instance_of(DeepHash)
      subject[:no].should  == "in between"
      subject["no"].should == "in between"
    end

    it "converts all Hash values into DeepHashes"  do
      subject.reverse_merge!({ :nested_1 => { 'nested_2' => { :leaf_3_also => "val3a" } }, :other1 => { "other2" => "other_val2" }})
      subject[:nested_1].should be_an_instance_of(DeepHash)
      subject[:nested_1][:nested_2].should be_an_instance_of(DeepHash)
      subject[:other1].should be_an_instance_of(DeepHash)
    end

    it "converts string keys to symbol keys even if they occur deep in the given hash" do
      merged = subject.reverse_merge({   'a' => { 'b' => { 'c' => { :d => :e }}}})
      merged[:a].should     == { :b  => { :c  => { :d => :e }}}
      merged[:a].should_not == { 'b' => { 'c' => { :d => :e }}}
    end

    it "DOES merge values where given hash has nil value" do
      subject.reverse_merge!(:a => { :b => nil }, :c => nil)
      subject[:a][:b].should be_nil
      subject[:c].should     be_nil
    end

    it "replaces child hashes, and does not merge them"  do
      deep_hash = subject.reverse_merge!({ :nested_1 => { 'nested_2' => { :leaf_3_also => "val3a" } },                     :other1 => { "other2" => "other_val2" }})
      deep_hash.should                == { :nested_1 => { :nested_2  => { :leaf_3      => "val3"  }, :leaf_2 => ['arr'] }, :other1 => { :other2 => "other_val2" }, :leaf_at_top => 'val1b' }
    end
  end

  context "#deep_merge!" do
    it "merges two subhashes when they share a key" do
      subject.deep_merge!(:nested_1 => { :nested_2  => { :leaf_3_also  => "val3a" } })
      subject.should == { :nested_1 => { :nested_2  => { :leaf_3_also  => "val3a", :leaf_3 => "val3" }, :leaf_2 => ['arr'] }, :leaf_at_top => 'val1b' }
    end

    it "merges two subhashes when they share a symbolized key" do
      subject.deep_merge!(:nested_1 => { "nested_2" => { "leaf_3_also" => "val3a" } })
      subject.should == { :nested_1 => { :nested_2  => { :leaf_3_also  => "val3a", :leaf_3 => "val3" }, :leaf_2 => ['arr'] }, :leaf_at_top => "val1b" }
    end

    it "preserves values in the original" do
      subject.deep_merge! :other_key => "other_val"
      subject[:nested_1][:leaf_2].should == ['arr']
      subject[:other_key].should == "other_val"
    end

    it "converts all Hash values into DeepHashes"  do
      subject.deep_merge!({:nested_1 => { :nested_2 => { :leaf_3_also => "val3a" } }, :other1 => { "other2" => "other_val2" }})
      subject[:nested_1].should be_an_instance_of(DeepHash)
      subject[:nested_1][:nested_2].should be_an_instance_of(DeepHash)
      subject[:other1].should be_an_instance_of(DeepHash)
    end

    it "converts string keys to symbol keys even if they occur deep in the given hash" do
      subject.deep_merge!({   'a' => { 'b' => { 'c' => { :d => :e }}}})
      subject[:a].should     == { :b  => { :c  => { :d => :e }}}
      subject[:a].should_not == { 'b' => { 'c' => { :d => :e }}}
    end

    it "replaces values from the given hash" do
      subject.deep_merge!(:nested_1 => { :nested_2 => { :leaf_3 => "new_val3" }, :leaf_2 => { "other2" => "other_val2" }})
      subject[:nested_1][:nested_2][:leaf_3].should == 'new_val3'
      subject[:nested_1][:leaf_2].should == { :other2 => "other_val2" }
    end

    it "replaces arrays and does not append to them" do
      subject.deep_merge!(:nested_1 => { :nested_2 => { :leaf_3 => [] }, :leaf_2 => ['val2'] })
      subject[:nested_1][:nested_2][:leaf_3].should == []
      subject[:nested_1][:leaf_2].should == ['val2']
    end

    it "does not replaces values where given hash has nil value" do
      subject.deep_merge!(:nested_1 => { :leaf_2 => nil }, :leaf_at_top => '')
      subject[:nested_1][:leaf_2].should == ['arr']
      subject[:leaf_at_top].should == ""
    end
  end

  context "#deep_set" do
    it 'should set a new value (single arg)' do
      subject.deep_set :new_key, 'new_val'
      subject[:new_key].should == 'new_val'
    end

    it 'should set a new value (multiple args)' do
      subject.deep_set :nested_1, :nested_2, :new_key, 'new_val'
      subject[:nested_1][:nested_2][:new_key].should == 'new_val'
    end

    it 'should replace an existing value (single arg)' do
      subject.deep_set :leaf_at_top, 'new_val'
      subject[:leaf_at_top].should == 'new_val'
    end

    it 'should replace an existing value (multiple args)' do
      subject.deep_set :nested_1, :nested_2, 'new_val'
      subject[:nested_1][:nested_2].should == 'new_val'
    end

    it 'should auto-vivify intermediate hashes' do
      subject.deep_set :one, :two, :three, :four, 'new_val'
      subject[:one][:two][:three][:four].should == 'new_val'
    end
  end

  context "#deep_delete" do
    it 'should remove the key from the array (multiple args)' do
      subject.deep_delete(:nested_1)
      subject[:nested_1].should be_nil
      subject.should == { :leaf_at_top => 'val1b'}
    end

    it 'should remove the key from the array (multiple args)' do
      subject.deep_delete(:nested_1, :nested_2, :leaf_3)
      subject[:nested_1][:nested_2][:leaf_3].should be_nil
      subject.should == {:leaf_at_top => "val1b", :nested_1 => {:leaf_2 => ['arr'], :nested_2 => {}}}
    end

    it 'should return the value if present (single args)' do
      returned_val = subject.deep_delete(:leaf_at_top)
      returned_val.should == 'val1b'
    end

    it 'should return the value if present (multiple args)' do
      returned_val = subject.deep_delete(:nested_1, :nested_2, :leaf_3)
      returned_val.should == 'val3'
    end

    it 'should return nil if the key is absent (single arg)' do
      returned_val = subject.deep_delete(:nested_1, :nested_2, :missing_key)
      returned_val.should be_nil
    end

    it 'should return nil if the key is absent (multiple args)' do
      returned_val = subject.deep_delete(:missing_key)
      returned_val.should be_nil
    end
  end
end
