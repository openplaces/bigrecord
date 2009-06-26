require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), "acts_as_solr_shared_spec"))

describe ActsAsSolr do

  describe "included in a model" do
    before(:each) do
      @model_class = Book
    end

    it_should_behave_like "a model with acts_as_solr"
  end

  describe "indexing functionality" do

    before(:each) do
      # TODO: This is specific to BigRecord and will need to be taken out
      Book.truncate

      Book.rebuild_index :silent => true, :drop => true
    end

    it "should insert new index data" do
      books = Book.find(:all, :conditions => "title:\"I Am Legend\"")
      books.size.should == 0

      book = Book.new(:title => "I Am Legend", :author => "Richard Matheson")
      book.save.should be_true

      books = Book.find(:all, :conditions => "title:\"I Am Legend\"")
      books.size.should == 1
      books.first.title.should == "I Am Legend"
    end

    it "#find_by_solr should return proper results given different terms" do
      book = Book.new(  :title => "I Am Legend",
                        :author => "Richard Matheson",
                        :description => "The most clever and riveting vampire novel since Dracula.")
      book.save.should be_true

      [ 'legend', 'i am', 'am', 'title:legend', 'title:legend AND author:richard',
        'author:matheson', 'author:richard', 'richard legend' ].each do |term|
        # Now verify the results
        results = Book.find_by_solr term
        results.total.should == 1

        results.docs.first.id.should ==  book.id
      end
    end

    it "#find_by_solr should search dynamic fields" do
      book = Book.new(  :title => "I Am Legend",
                        :author => "Richard Matheson",
                        :description => "The most clever and riveting vampire novel since Dracula.")
      book.save.should be_true

      date = Time.now.strftime('%b %d %Y')

      ["legend AND #{date}", "author:richard AND #{date}", "richard legend #{date}",
        "legend #{date}"].each do |term|
        results = Book.find_by_solr term

        results.total.should == 1
        results.docs.first.id.should == book.id
      end
    end

    it "#find_id_by_solr should return a list of ids as the results" do
      book = Book.new(  :title => "I Am Legend",
                        :author => "Richard Matheson",
                        :description => "The most clever and riveting vampire novel since Dracula.")
      book.save.should be_true

      [ 'legend', 'i am', 'am', 'title:legend', 'title:legend AND author:richard',
        'author:matheson', 'author:richard', 'richard legend' ].each do |term|
        # Now verify the results
        results = Book.find_id_by_solr term
        results.total.should == 1

        results.docs.should ==  [book.id]
      end
    end

    it "#find_by_solr should correctly search with html entities" do
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
        results = Book.find_by_solr term

        results.total.should == 1
        results.docs.first.id.should == book.id
      end
    end

    it "#find_by_solr should raise an error if an invalid operator is passed to it" do
      pending "Doesn't seem to work anymore"

      lambda{
        Book.find_by_solr "random search term", :operator => :or
        Book.find_by_solr "random search term", :operator => :and
      }.should_not raise_error

      lambda{
        Book.find_by_solr "random search term", :operator => :bad
      }.should raise_error(RuntimeError)
    end

  end

end
