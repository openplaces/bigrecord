require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), "index_shared_spec"))

describe BigIndex::Resource do

  describe "included in a model" do

    before(:each) do
      @model_class = Book
      Book.delete_all

      Book.drop_index
      Animal.drop_index
    end

    it_should_behave_like "a model with BigIndex::Resource"

    it "should choose the proper fields in the model to index" do

      # The expected fields (and their types) to be indexed for the Book model
      book_expected = [ {:title => :string},
                        {:author => :string},
                        {:description => :text} ]

      book_expected.each do |h|
        # The indexed fields should contain the expected attributes/field names
        Book.index_views_hash[:default].map{|x| x.field_name}.should include(h.keys.first)

        # Now we check that only one field matches that name
        Book.index_views_hash[:default].select{|x| x.field_name == h.keys.first}.size.should == 1

        # And the type of that field should match the expected type
        Book.index_views_hash[:default].select{|x| x.field_name == h.keys.first}.first.field_type.should == h.values.first
      end

      # The expected fields (and their types) to be indexed for the Animal model
      animal_expected = [ {:name => :text},
                          {:description => :text} ]

      animal_expected.each do |h|
        # The indexed fields should contain the expected attributes/field names
        Animal.index_views_hash[:default].map{|x| x.field_name}.should include(h.keys.first)

        # Now we check that only one field matches that name
        Animal.index_views_hash[:default].select{|x| x.field_name == h.keys.first}.size.should == 1

        # And the type of that field should match the expected type
        Animal.index_views_hash[:default].select{|x| x.field_name == h.keys.first}.first.field_type.should == h.values.first
      end
    end

  end

  describe "indexing functionality" do

    before(:each) do
      # TODO: This is specific to BigRecord and will need to be taken out
      Book.delete_all
      Animal.delete_all

      Book.rebuild_index :silent => true, :drop => true
      Animal.rebuild_index :silent => true, :drop => true
    end

    it "should insert new index data" do
      books = Book.find(:all, :conditions => "title:\"I Am Legend\"")
      books.size.should == 0

      book = Book.new(:title => "I Am Legend", :author => "Richard Matheson")
      book.save.should be_true

      books_check = Book.find(:all, :conditions => "title:\"I Am Legend\"")
      books_check.size.should == 1
      books_check.first.title.should == "I Am Legend"
    end

    it "indexed #find should return proper results given different terms" do
      book = Book.new(  :title => "I Am Legend",
                        :author => "Richard Matheson",
                        :description => "The most clever and riveting vampire novel since Dracula.")
      book.save.should be_true

      [ 'I Am Legend', 'i am', 'am', 'legend', 'legend AND author:"Richard Matheson"',
        'author:"Richard Matheson"', 'richard', 'richard legend' ].each do |term|
        # Now verify the results
        results = Book.find(:all, :conditions => term)
        results.size.should == 1

        results.first.id.should == book.id
      end
    end

    it "indexed #find should search dynamic fields" do
      book = Book.new(  :title => "I Am Legend",
                        :author => "Richard Matheson",
                        :description => "The most clever and riveting vampire novel since Dracula.")
      book.save.should be_true

      date = Time.now.strftime('%b %d %Y')

      ["#{date}", "author:\"Richard Matheson\" AND #{date}", "title:\"I Am Legend\" #{date}"].each do |term|
        results = Book.find(:all, :conditions => term)

        results.size.should == 1
        results.first.id.should == book.id
      end
    end

    it "#find_id_by_solr should return a list of ids as the results" do
      book = Book.new(  :title => "I Am Legend",
                        :author => "Richard Matheson",
                        :description => "The most clever and riveting vampire novel since Dracula.")
      book.save.should be_true

      [ 'legend', 'i am', 'am', 'title:"I Am Legend"', 'title:"I Am Legend" AND author:"Richard Matheson"',
        'matheson', 'richard', 'richard legend' ].each do |term|
        # Now verify the results
        results = Book.find(:all, :conditions => term, :format => :ids)
        results.size.should == 1

        results.should ==  [book.id]
      end
    end

    it "#find should correctly search with html entities" do
      description = "
      inverted exclamation mark  	&iexcl;  	&#161;
      ¤ 	currency 	&curren; 	&#164;
      ¢ 	cent 	&cent; 	&#162;
      £ 	pound 	&pound; 	&#163;
      ¥ 	yen 	&yen; 	&#165;
      ¦ 	broken vertical bar 	&brvbar; 	&#166;
      § 	section 	&sect; 	&#167;
      ¨ 	spacing diaeresis 	&uml; 	&#168;
      © 	copyright 	&copy; 	&#169;
      ª 	feminine ordinal indicator 	&ordf; 	&#170;
      « 	angle quotation mark (left) 	&laquo; 	&#171;
      ¬ 	negation 	&not; 	&#172;
      ­ 	soft hyphen 	&shy; 	&#173;
      ® 	registered trademark 	&reg; 	&#174;
      ™ 	trademark 	&trade; 	&#8482;
      ¯ 	spacing macron 	&macr; 	&#175;
      ° 	degree 	&deg; 	&#176;
      ± 	plus-or-minus  	&plusmn; 	&#177;
      ² 	superscript 2 	&sup2; 	&#178;
      ³ 	superscript 3 	&sup3; 	&#179;
      ´ 	spacing acute 	&acute; 	&#180;
      µ 	micro 	&micro; 	&#181;
      ¶ 	paragraph 	&para; 	&#182;
      · 	middle dot 	&middot; 	&#183;
      ¸ 	spacing cedilla 	&cedil; 	&#184;
      ¹ 	superscript 1 	&sup1; 	&#185;
      º 	masculine ordinal indicator 	&ordm; 	&#186;
      » 	angle quotation mark (right) 	&raquo; 	&#187;
      ¼ 	fraction 1/4 	&frac14; 	&#188;
      ½ 	fraction 1/2 	&frac12; 	&#189;
      ¾ 	fraction 3/4 	&frac34; 	&#190;
      ¿ 	inverted question mark 	&iquest; 	&#191;
      × 	multiplication 	&times; 	&#215;
      ÷ 	division 	&divide; 	&#247
          &hearts; &diams; &clubs; &spades;"

      book = Book.new(  :title => "I Am Legend",
                        :author => "Richard Matheson",
                        :description => description)
      book.save.should be_true

      description_keywords = description.split(/[\s\t\n]+/).compact.reject{|x| x.blank?}.map{|x| x.gsub(";", "")}

      # Verifying that if we use any of the words in description, that it'll find the right record.
      description_keywords.each do |term|
        results = Book.find(:all, :conditions => term)

        results.size.should == 1
        results.first.id.should == book.id
      end
    end

    it "should create dynamic finders based on the indexed fields (i.e. find_by_attribute() methods)" do
      result = Book.new

      Book.should respond_to(:find_by_title)
      Book.should respond_to(:find_by_author)

      # It should dispatch a call to #find_by_index with some defined conditions
      Book.index_adapter.should_receive(:find_by_index).with(Book, "title:(\"I Am Legend\")", an_instance_of(Hash)).and_return([result])
      Book.find_by_title("I Am Legend").should == [result]

      Book.index_adapter.should_receive(:find_by_index).with(Book, "author:(\"Richard Matheson\")", an_instance_of(Hash)).and_return([result])
      Book.find_by_author("Richard Matheson").should == [result]
    end

    it "#find should return raw index search results when requested" do
      book = Book.new(  :title => "I Am Legend",
                        :author => "Richard Matheson",
                        :description => "The most clever and riveting vampire novel since Dracula.")
      book.save.should be_true

      results = Book.find(:all, :conditions => "legend", :raw_result => true)

      results.should respond_to(:total_hits)
      results.should respond_to(:results)
    end

  end

end
