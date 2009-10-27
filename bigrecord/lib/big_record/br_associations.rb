dir = File.expand_path(File.join(File.dirname(__FILE__), "br_associations"))

require dir + '/association_proxy'
require dir + '/association_collection'
require dir + '/belongs_to_association'
require dir + '/belongs_to_many_association'
require dir + '/has_one_association'
require dir + '/has_and_belongs_to_many_association'

module BigRecord
  module BrAssociations # :nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Associations are a set of macro-like class methods for tying objects together through foreign keys. They express relationships like
    # "Project has one Project Manager" or "Project belongs to a Portfolio". Each macro adds a number of methods to the class which are
    # specialized according to the collection or association symbol and the options hash. It works much the same way as Ruby's own attr*
    # methods. Example:
    #
    #   class Project < BigRecord::Base
    #     belongs_to              :portfolio
    #     has_one                 :project_manager
    #     has_many                :milestones
    #     has_and_belongs_to_many :categories
    #   end
    #
    # The project class now has the following methods (and more) to ease the traversal and manipulation of its relationships:
    # * <tt>Project#portfolio, Project#portfolio=(portfolio), Project#portfolio.nil?</tt>
    # * <tt>Project#project_manager, Project#project_manager=(project_manager), Project#project_manager.nil?,</tt>
    # * <tt>Project#milestones.empty?, Project#milestones.size, Project#milestones, Project#milestones<<(milestone),</tt>
    #   <tt>Project#milestones.delete(milestone), Project#milestones.find(milestone_id), Project#milestones.find(:all, options),</tt>
    #   <tt>Project#milestones.build, Project#milestones.create</tt>
    # * <tt>Project#categories.empty?, Project#categories.size, Project#categories, Project#categories<<(category1),</tt>
    #   <tt>Project#categories.delete(category1)</tt>
    #
    # == Example
    #
    # link:files/examples/associations.png
    #
    # == Is it belongs_to or has_one?
    #
    # Both express a 1-1 relationship, the difference is mostly where to place the foreign key, which goes on the table for the class
    # saying belongs_to. Example:
    #
    #   class User < BigRecord::Base
    #     # I reference an account.
    #     belongs_to :account
    #   end
    #
    #   class Account < BigRecord::Base
    #     # One user references me.
    #     has_one :user
    #   end
    #
    # The tables for these classes could look something like:
    #
    #   CREATE TABLE users (
    #     id int(11) NOT NULL auto_increment,
    #     account_id int(11) default NULL,
    #     name varchar default NULL,
    #     PRIMARY KEY  (id)
    #   )
    #
    #   CREATE TABLE accounts (
    #     id int(11) NOT NULL auto_increment,
    #     name varchar default NULL,
    #     PRIMARY KEY  (id)
    #   )
    #
    # == Unsaved objects and associations
    #
    # You can manipulate objects and associations before they are saved to the database, but there is some special behaviour you should be
    # aware of, mostly involving the saving of associated objects.
    #
    # === One-to-one associations
    #
    # * Assigning an object to a has_one association automatically saves that object and the object being replaced (if there is one), in
    #   order to update their primary keys - except if the parent object is unsaved (new_record? == true).
    # * If either of these saves fail (due to one of the objects being invalid) the assignment statement returns false and the assignment
    #   is cancelled.
    # * If you wish to assign an object to a has_one association without saving it, use the #association.build method (documented below).
    # * Assigning an object to a belongs_to association does not save the object, since the foreign key field belongs on the parent. It does
    #   not save the parent either.
    #
    # === Collections
    #
    # * Adding an object to a collection (has_many or has_and_belongs_to_many) automatically saves that object, except if the parent object
    #   (the owner of the collection) is not yet stored in the database.
    # * If saving any of the objects being added to a collection (via #push or similar) fails, then #push returns false.
    # * You can add an object to a collection without automatically saving it by using the #collection.build method (documented below).
    # * All unsaved (new_record? == true) members of the collection are automatically saved when the parent is saved.
    #
    # === Association callbacks
    #
    # Similiar to the normal callbacks that hook into the lifecycle of an Active Record object, you can also define callbacks that get
    # trigged when you add an object to or removing an object from a association collection. Example:
    #
    #   class Project
    #     has_and_belongs_to_many :developers, :after_add => :evaluate_velocity
    #
    #     def evaluate_velocity(developer)
    #       ...
    #     end
    #   end
    #
    # It's possible to stack callbacks by passing them as an array. Example:
    #
    #   class Project
    #     has_and_belongs_to_many :developers, :after_add => [:evaluate_velocity, Proc.new { |p, d| p.shipping_date = Time.now}]
    #   end
    #
    # Possible callbacks are: before_add, after_add, before_remove and after_remove.
    #
    # Should any of the before_add callbacks throw an exception, the object does not get added to the collection. Same with
    # the before_remove callbacks, if an exception is thrown the object doesn't get removed.
    #
    # === Association extensions
    #
    # The proxy objects that controls the access to associations can be extended through anonymous modules. This is especially
    # beneficial for adding new finders, creators, and other factory-type methods that are only used as part of this association.
    # Example:
    #
    #   class Account < BigRecord::Base
    #     has_many :people do
    #       def find_or_create_by_name(name)
    #         first_name, last_name = name.split(" ", 2)
    #         find_or_create_by_first_name_and_last_name(first_name, last_name)
    #       end
    #     end
    #   end
    #
    #   person = Account.find(:first).people.find_or_create_by_name("David Heinemeier Hansson")
    #   person.first_name # => "David"
    #   person.last_name  # => "Heinemeier Hansson"
    #
    # If you need to share the same extensions between many associations, you can use a named extension module. Example:
    #
    #   module FindOrCreateByNameExtension
    #     def find_or_create_by_name(name)
    #       first_name, last_name = name.split(" ", 2)
    #       find_or_create_by_first_name_and_last_name(first_name, last_name)
    #     end
    #   end
    #
    #   class Account < BigRecord::Base
    #     has_many :people, :extend => FindOrCreateByNameExtension
    #   end
    #
    #   class Company < BigRecord::Base
    #     has_many :people, :extend => FindOrCreateByNameExtension
    #   end
    #
    # If you need to use multiple named extension modules, you can specify an array of modules with the :extend option.
    # In the case of name conflicts between methods in the modules, methods in modules later in the array supercede
    # those earlier in the array. Example:
    #
    #   class Account < BigRecord::Base
    #     has_many :people, :extend => [FindOrCreateByNameExtension, FindRecentExtension]
    #   end
    #
    # Some extensions can only be made to work with knowledge of the association proxy's internals.
    # Extensions can access relevant state using accessors on the association proxy:
    #
    # * +proxy_owner+ - Returns the object the association is part of.
    # * +proxy_reflection+ - Returns the reflection object that describes the association.
    # * +proxy_target+ - Returns the associated object for belongs_to and has_one, or the collection of associated objects for has_many and has_and_belongs_to_many.
    #
    # === Association Join Models
    #
    # Has Many associations can be configured with the :through option to use an explicit join model to retrieve the data.  This
    # operates similarly to a <tt>has_and_belongs_to_many</tt> association.  The advantage is that you're able to add validations,
    # callbacks, and extra attributes on the join model.  Consider the following schema:
    #
    #   class Author < BigRecord::Base
    #     has_many :authorships
    #     has_many :books, :through => :authorships
    #   end
    #
    #   class Authorship < BigRecord::Base
    #     belongs_to :author
    #     belongs_to :book
    #   end
    #
    #   @author = Author.find :first
    #   @author.authorships.collect { |a| a.book } # selects all books that the author's authorships belong to.
    #   @author.books                              # selects all books by using the Authorship join model
    #
    # You can also go through a has_many association on the join model:
    #
    #   class Firm < BigRecord::Base
    #     has_many   :clients
    #     has_many   :invoices, :through => :clients
    #   end
    #
    #   class Client < BigRecord::Base
    #     belongs_to :firm
    #     has_many   :invoices
    #   end
    #
    #   class Invoice < BigRecord::Base
    #     belongs_to :client
    #   end
    #
    #   @firm = Firm.find :first
    #   @firm.clients.collect { |c| c.invoices }.flatten # select all invoices for all clients of the firm
    #   @firm.invoices                                   # selects all invoices by going through the Client join model.
    #
    # === Polymorphic Associations
    #
    # Polymorphic associations on models are not restricted on what types of models they can be associated with.  Rather, they
    # specify an interface that a has_many association must adhere to.
    #
    #   class Asset < BigRecord::Base
    #     belongs_to :attachable, :polymorphic => true
    #   end
    #
    #   class Post < BigRecord::Base
    #     has_many :assets, :as => :attachable         # The <tt>:as</tt> option specifies the polymorphic interface to use.
    #   end
    #
    #   @asset.attachable = @post
    #
    # This works by using a type column in addition to a foreign key to specify the associated record.  In the Asset example, you'd need
    # an attachable_id integer column and an attachable_type string column.
    #
    # Using polymorphic associations in combination with single table inheritance (STI) is a little tricky. In order
    # for the associations to work as expected, ensure that you store the base model for the STI models in the
    # type column of the polymorphic association. To continue with the asset example above, suppose there are guest posts
    # and member posts that use the posts table for STI. So there will be an additional 'type' column in the posts table.
    #
    #   class Asset < BigRecord::Base
    #     belongs_to :attachable, :polymorphic => true
    #
    #     def attachable_type=(sType)
    #        super(sType.to_s.classify.constantize.base_class.to_s)
    #     end
    #   end
    #
    #   class Post < BigRecord::Base
    #     # because we store "Post" in attachable_type now :dependent => :destroy will work
    #     has_many :assets, :as => :attachable, :dependent => :destroy
    #   end
    #
    #   class GuestPost < BigRecord::Base
    #   end
    #
    #   class MemberPost < BigRecord::Base
    #   end
    #
    # == Caching
    #
    # All of the methods are built on a simple caching principle that will keep the result of the last query around unless specifically
    # instructed not to. The cache is even shared across methods to make it even cheaper to use the macro-added methods without
    # worrying too much about performance at the first go. Example:
    #
    #   project.milestones             # fetches milestones from the database
    #   project.milestones.size        # uses the milestone cache
    #   project.milestones.empty?      # uses the milestone cache
    #   project.milestones(true).size  # fetches milestones from the database
    #   project.milestones             # uses the milestone cache
    #
    # == Eager loading of associations
    #
    # Eager loading is a way to find objects of a certain class and a number of named associations along with it in a single SQL call. This is
    # one of the easiest ways of to prevent the dreaded 1+N problem in which fetching 100 posts that each needs to display their author
    # triggers 101 database queries. Through the use of eager loading, the 101 queries can be reduced to 1. Example:
    #
    #   class Post < BigRecord::Base
    #     belongs_to :author
    #     has_many   :comments
    #   end
    #
    # Consider the following loop using the class above:
    #
    #   for post in Post.find(:all)
    #     puts "Post:            " + post.title
    #     puts "Written by:      " + post.author.name
    #     puts "Last comment on: " + post.comments.first.created_on
    #   end
    #
    # To iterate over these one hundred posts, we'll generate 201 database queries. Let's first just optimize it for retrieving the author:
    #
    #   for post in Post.find(:all, :include => :author)
    #
    # This references the name of the belongs_to association that also used the :author symbol, so the find will now weave in a join something
    # like this: LEFT OUTER JOIN authors ON authors.id = posts.author_id. Doing so will cut down the number of queries from 201 to 101.
    #
    # We can improve upon the situation further by referencing both associations in the finder with:
    #
    #   for post in Post.find(:all, :include => [ :author, :comments ])
    #
    # That'll add another join along the lines of: LEFT OUTER JOIN comments ON comments.post_id = posts.id. And we'll be down to 1 query.
    # But that shouldn't fool you to think that you can pull out huge amounts of data with no performance penalty just because you've reduced
    # the number of queries. The database still needs to send all the data to Active Record and it still needs to be processed. So it's no
    # catch-all for performance problems, but it's a great way to cut down on the number of queries in a situation as the one described above.
    #
    # Since the eager loading pulls from multiple tables, you'll have to disambiguate any column references in both conditions and orders. So
    # :order => "posts.id DESC" will work while :order => "id DESC" will not. Because eager loading generates the SELECT statement too, the
    # :select option is ignored.
    #
    # You can use eager loading on multiple associations from the same table, but you cannot use those associations in orders and conditions
    # as there is currently not any way to disambiguate them. Eager loading will not pull additional attributes on join tables, so "rich
    # associations" with has_and_belongs_to_many are not a good fit for eager loading.
    #
    # When eager loaded, conditions are interpolated in the context of the model class, not the model instance.  Conditions are lazily interpolated
    # before the actual model exists.
    #
    # == Table Aliasing
    #
    # BigRecord uses table aliasing in the case that a table is referenced multiple times in a join.  If a table is referenced only once,
    # the standard table name is used.  The second time, the table is aliased as #{reflection_name}_#{parent_table_name}.  Indexes are appended
    # for any more successive uses of the table name.
    #
    #   Post.find :all, :include => :comments
    #   # => SELECT ... FROM posts LEFT OUTER JOIN comments ON ...
    #   Post.find :all, :include => :special_comments # STI
    #   # => SELECT ... FROM posts LEFT OUTER JOIN comments ON ... AND comments.type = 'SpecialComment'
    #   Post.find :all, :include => [:comments, :special_comments] # special_comments is the reflection name, posts is the parent table name
    #   # => SELECT ... FROM posts LEFT OUTER JOIN comments ON ... LEFT OUTER JOIN comments special_comments_posts
    #
    # Acts as tree example:
    #
    #   TreeMixin.find :all, :include => :children
    #   # => SELECT ... FROM mixins LEFT OUTER JOIN mixins childrens_mixins ...
    #   TreeMixin.find :all, :include => {:children => :parent} # using cascading eager includes
    #   # => SELECT ... FROM mixins LEFT OUTER JOIN mixins childrens_mixins ...
    #                               LEFT OUTER JOIN parents_mixins ...
    #   TreeMixin.find :all, :include => {:children => {:parent => :children}}
    #   # => SELECT ... FROM mixins LEFT OUTER JOIN mixins childrens_mixins ...
    #                               LEFT OUTER JOIN parents_mixins ...
    # LEFT OUTER JOIN mixins childrens_mixins_2
    #
    # Has and Belongs to Many join tables use the same idea, but add a _join suffix:
    #
    #   Post.find :all, :include => :categories
    #   # => SELECT ... FROM posts LEFT OUTER JOIN categories_posts ... LEFT OUTER JOIN categories ...
    #   Post.find :all, :include => {:categories => :posts}
    #   # => SELECT ... FROM posts LEFT OUTER JOIN categories_posts ... LEFT OUTER JOIN categories ...
    #                              LEFT OUTER JOIN categories_posts posts_categories_join LEFT OUTER JOIN posts posts_categories
    #   Post.find :all, :include => {:categories => {:posts => :categories}}
    #   # => SELECT ... FROM posts LEFT OUTER JOIN categories_posts ... LEFT OUTER JOIN categories ...
    #                              LEFT OUTER JOIN categories_posts posts_categories_join LEFT OUTER JOIN posts posts_categories
    #                              LEFT OUTER JOIN categories_posts categories_posts_join LEFT OUTER JOIN categories categories_posts
    #
    # If you wish to specify your own custom joins using a :joins option, those table names will take precedence over the eager associations..
    #
    #   Post.find :all, :include => :comments, :joins => "inner join comments ..."
    #   # => SELECT ... FROM posts LEFT OUTER JOIN comments_posts ON ... INNER JOIN comments ...
    #   Post.find :all, :include => [:comments, :special_comments], :joins => "inner join comments ..."
    #   # => SELECT ... FROM posts LEFT OUTER JOIN comments comments_posts ON ...
    #                              LEFT OUTER JOIN comments special_comments_posts ...
    #                              INNER JOIN comments ...
    #
    # Table aliases are automatically truncated according to the maximum length of table identifiers according to the specific database.
    #
    # == Modules
    #
    # By default, associations will look for objects within the current module scope. Consider:
    #
    #   module MyApplication
    #     module Business
    #       class Firm < BigRecord::Base
    #          has_many :clients
    #        end
    #
    #       class Company < BigRecord::Base; end
    #     end
    #   end
    #
    # When Firm#clients is called, it'll in turn call <tt>MyApplication::Business::Company.find(firm.id)</tt>. If you want to associate
    # with a class in another module scope this can be done by specifying the complete class name, such as:
    #
    #   module MyApplication
    #     module Business
    #       class Firm < BigRecord::Base; end
    #     end
    #
    #     module Billing
    #       class Account < BigRecord::Base
    #         belongs_to :firm, :class_name => "MyApplication::Business::Firm"
    #       end
    #     end
    #   end
    #
    # == Type safety with BigRecord::AssociationTypeMismatch
    #
    # If you attempt to assign an object to an association that doesn't match the inferred or specified <tt>:class_name</tt>, you'll
    # get a BigRecord::AssociationTypeMismatch.
    #
    # == Options
    #
    # All of the association macros can be specialized through options which makes more complex cases than the simple and guessable ones
    # possible.
    module ClassMethods
      # Adds the following methods for retrieval and query of collections of associated objects.
      # +collection+ is replaced with the symbol passed as the first argument, so
      # <tt>has_many :clients</tt> would add among others <tt>clients.empty?</tt>.
      # * <tt>collection(force_reload = false)</tt> - returns an array of all the associated objects.
      #   An empty array is returned if none are found.
      # * <tt>collection<<(object, ...)</tt> - adds one or more objects to the collection by setting their foreign keys to the collection's primary key.
      # * <tt>collection.delete(object, ...)</tt> - removes one or more objects from the collection by setting their foreign keys to NULL.
      #   This will also destroy the objects if they're declared as belongs_to and dependent on this model.
      # * <tt>collection=objects</tt> - replaces the collections content by deleting and adding objects as appropriate.
      # * <tt>collection_singular_ids</tt> - returns an array of the associated objects ids
      # * <tt>collection_singular_ids=ids</tt> - replace the collection by the objects identified by the primary keys in +ids+
      # * <tt>collection.clear</tt> - removes every object from the collection. This destroys the associated objects if they
      #   are <tt>:dependent</tt>, deletes them directly from the database if they are <tt>:dependent => :delete_all</tt>,
      #   and sets their foreign keys to NULL otherwise.
      # * <tt>collection.empty?</tt> - returns true if there are no associated objects.
      # * <tt>collection.size</tt> - returns the number of associated objects.
      # * <tt>collection.find</tt> - finds an associated object according to the same rules as Base.find.
      # * <tt>collection.build(attributes = {})</tt> - returns a new object of the collection type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key but has not yet been saved. *Note:* This only works if an
      #   associated object already exists, not if it's nil!
      # * <tt>collection.create(attributes = {})</tt> - returns a new object of the collection type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key and that has already been saved (if it passed the validation).
      #   *Note:* This only works if an associated object already exists, not if it's nil!
      #
      # Example: A Firm class declares <tt>has_many :clients</tt>, which will add:
      # * <tt>Firm#clients</tt> (similar to <tt>Clients.find :all, :conditions => "firm_id = #{id}"</tt>)
      # * <tt>Firm#clients<<</tt>
      # * <tt>Firm#clients.delete</tt>
      # * <tt>Firm#clients=</tt>
      # * <tt>Firm#client_ids</tt>
      # * <tt>Firm#client_ids=</tt>
      # * <tt>Firm#clients.clear</tt>
      # * <tt>Firm#clients.empty?</tt> (similar to <tt>firm.clients.size == 0</tt>)
      # * <tt>Firm#clients.size</tt> (similar to <tt>Client.count "firm_id = #{id}"</tt>)
      # * <tt>Firm#clients.find</tt> (similar to <tt>Client.find(id, :conditions => "firm_id = #{id}")</tt>)
      # * <tt>Firm#clients.build</tt> (similar to <tt>Client.new("firm_id" => id)</tt>)
      # * <tt>Firm#clients.create</tt> (similar to <tt>c = Client.new("firm_id" => id); c.save; c</tt>)
      # The declaration can also include an options hash to specialize the behavior of the association.
      #
      # Options are:
      # * <tt>:class_name</tt>  - specify the class name of the association. Use it only if that name can't be inferred
      #   from the association name. So <tt>has_many :products</tt> will by default be linked to the +Product+ class, but
      #   if the real class name is +SpecialProduct+, you'll have to specify it with this option.
      # * <tt>:conditions</tt>  - specify the conditions that the associated objects must meet in order to be included as a "WHERE"
      #   sql fragment, such as "price > 5 AND name LIKE 'B%'".
      # * <tt>:order</tt>       - specify the order in which the associated objects are returned as a "ORDER BY" sql fragment,
      #   such as "last_name, first_name DESC"
      # * <tt>:group</tt>       - specify the attribute by which the associated objects are returned as a "GROUP BY" sql fragment,
      #   such as "category"
      # * <tt>:foreign_key</tt> - specify the foreign key used for the association. By default this is guessed to be the name
      #   of this class in lower-case and "_id" suffixed. So a +Person+ class that makes a has_many association will use "person_id"
      #   as the default foreign_key.
      # * <tt>:dependent</tt>   - if set to :destroy all the associated objects are destroyed
      #   alongside this object by calling their destroy method.  If set to :delete_all all associated
      #   objects are deleted *without* calling their destroy method.  If set to :nullify all associated
      #   objects' foreign keys are set to NULL *without* calling their save callbacks.
      #   NOTE: :dependent => true is deprecated and has been replaced with :dependent => :destroy.
      #   May not be set if :exclusively_dependent is also set.
      # * <tt>:exclusively_dependent</tt>   - Deprecated; equivalent to :dependent => :delete_all. If set to true all
      #   the associated object are deleted in one SQL statement without having their
      #   before_destroy callback run. This should only be used on associations that depend solely on this class and don't need to do any
      #   clean-up in before_destroy. The upside is that it's much faster, especially if there's a counter_cache involved.
      #   May not be set if :dependent is also set.
      # * <tt>:finder_sql</tt>  - specify a complete SQL statement to fetch the association. This is a good way to go for complex
      #   associations that depend on multiple tables. Note: When this option is used, +find_in_collection+ is _not_ added.
      # * <tt>:counter_sql</tt>  - specify a complete SQL statement to fetch the size of the association. If +:finder_sql+ is
      #   specified but +:counter_sql+, +:counter_sql+ will be generated by replacing SELECT ... FROM with SELECT COUNT(*) FROM.
      # * <tt>:extend</tt>  - specify a named module for extending the proxy, see "Association extensions".
      # * <tt>:include</tt>  - specify second-order associations that should be eager loaded when the collection is loaded.
      # * <tt>:group</tt>: An attribute name by which the result should be grouped. Uses the GROUP BY SQL-clause.
      # * <tt>:limit</tt>: An integer determining the limit on the number of rows that should be returned.
      # * <tt>:offset</tt>: An integer determining the offset from where the rows should be fetched. So at 5, it would skip the first 4 rows.
      # * <tt>:select</tt>: By default, this is * as in SELECT * FROM, but can be changed if you for example want to do a join, but not
      #   include the joined columns.
      # * <tt>:as</tt>: Specifies a polymorphic interface (See #belongs_to).
      # * <tt>:through</tt>: Specifies a Join Model to perform the query through.  Options for <tt>:class_name</tt> and <tt>:foreign_key</tt>
      #   are ignored, as the association uses the source reflection.  You can only use a <tt>:through</tt> query through a <tt>belongs_to</tt>
      #   or <tt>has_many</tt> association.
      # * <tt>:source</tt>: Specifies the source association name used by <tt>has_many :through</tt> queries.  Only use it if the name cannot be
      #   inferred from the association.  <tt>has_many :subscribers, :through => :subscriptions</tt> will look for either +:subscribers+ or
      #   +:subscriber+ on +Subscription+, unless a +:source+ is given.
      # * <tt>:source_type</tt>: Specifies type of the source association used by <tt>has_many :through</tt> queries where the source association
      #   is a polymorphic belongs_to.
      # * <tt>:uniq</tt> - if set to true, duplicates will be omitted from the collection. Useful in conjunction with :through.
      #
      # Option examples:
      #   has_many :comments, :order => "posted_on"
      #   has_many :comments, :include => :author
      #   has_many :people, :class_name => "Person", :conditions => "deleted = 0", :order => "name"
      #   has_many :tracks, :order => "position", :dependent => :destroy
      #   has_many :comments, :dependent => :nullify
      #   has_many :tags, :as => :taggable
      #   has_many :subscribers, :through => :subscriptions, :source => :user
      #   has_many :subscribers, :class_name => "Person", :finder_sql =>
      #       'SELECT DISTINCT people.* ' +
      #       'FROM people p, post_subscriptions ps ' +
      #       'WHERE ps.post_id = #{id} AND ps.person_id = p.id ' +
      #       'ORDER BY p.first_name'
      def has_many_big_records(association_id, options = {}, &extension)
        reflection = create_has_many_big_records_reflection(association_id, options, &extension)

        configure_dependency_for_has_many(reflection)

        if options[:through]
          collection_reader_method(reflection, HasManyThroughAssociation)
        else
          add_association_callbacks(reflection.name, reflection.options)
          collection_accessor_methods(reflection, HasManyAssociation)
        end

#        add_deprecated_api_for_has_many(reflection.name)
      end

      alias_method :has_many_bigrecords, :has_many_big_records

      # Adds the following methods for retrieval and query of a single associated object.
      # +association+ is replaced with the symbol passed as the first argument, so
      # <tt>has_one :manager</tt> would add among others <tt>manager.nil?</tt>.
      # * <tt>association(force_reload = false)</tt> - returns the associated object. Nil is returned if none is found.
      # * <tt>association=(associate)</tt> - assigns the associate object, extracts the primary key, sets it as the foreign key,
      #   and saves the associate object.
      # * <tt>association.nil?</tt> - returns true if there is no associated object.
      # * <tt>build_association(attributes = {})</tt> - returns a new object of the associated type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key but has not yet been saved. Note: This ONLY works if
      #   an association already exists. It will NOT work if the association is nil.
      # * <tt>create_association(attributes = {})</tt> - returns a new object of the associated type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key and that has already been saved (if it passed the validation).
      #
      # Example: An Account class declares <tt>has_one :beneficiary</tt>, which will add:
      # * <tt>Account#beneficiary</tt> (similar to <tt>Beneficiary.find(:first, :conditions => "account_id = #{id}")</tt>)
      # * <tt>Account#beneficiary=(beneficiary)</tt> (similar to <tt>beneficiary.account_id = account.id; beneficiary.save</tt>)
      # * <tt>Account#beneficiary.nil?</tt>
      # * <tt>Account#build_beneficiary</tt> (similar to <tt>Beneficiary.new("account_id" => id)</tt>)
      # * <tt>Account#create_beneficiary</tt> (similar to <tt>b = Beneficiary.new("account_id" => id); b.save; b</tt>)
      #
      # The declaration can also include an options hash to specialize the behavior of the association.
      #
      # Options are:
      # * <tt>:class_name</tt>  - specify the class name of the association. Use it only if that name can't be inferred
      #   from the association name. So <tt>has_one :manager</tt> will by default be linked to the +Manager+ class, but
      #   if the real class name is +Person+, you'll have to specify it with this option.
      # * <tt>:conditions</tt>  - specify the conditions that the associated object must meet in order to be included as a "WHERE"
      #   sql fragment, such as "rank = 5".
      # * <tt>:order</tt>       - specify the order from which the associated object will be picked at the top. Specified as
      #    an "ORDER BY" sql fragment, such as "last_name, first_name DESC"
      # * <tt>:dependent</tt>   - if set to :destroy (or true) the associated object is destroyed when this object is. If set to
      #   :delete the associated object is deleted *without* calling its destroy method. If set to :nullify the associated
      #   object's foreign key is set to NULL. Also, association is assigned.
      # * <tt>:foreign_key</tt> - specify the foreign key used for the association. By default this is guessed to be the name
      #   of this class in lower-case and "_id" suffixed. So a +Person+ class that makes a has_one association will use "person_id"
      #   as the default foreign_key.
      # * <tt>:include</tt>  - specify second-order associations that should be eager loaded when this object is loaded.
      # * <tt>:as</tt>: Specifies a polymorphic interface (See #belongs_to).
            #
      # Option examples:
      #   has_one :credit_card, :dependent => :destroy  # destroys the associated credit card
      #   has_one :credit_card, :dependent => :nullify  # updates the associated records foriegn key value to null rather than destroying it
      #   has_one :last_comment, :class_name => "Comment", :order => "posted_on"
      #   has_one :project_manager, :class_name => "Person", :conditions => "role = 'project_manager'"
      #   has_one :attachment, :as => :attachable
      def has_one_big_record(association_id, options = {})
        reflection = create_has_one_big_record_reflection(association_id, options)

        module_eval do
          after_save <<-EOF
            association = instance_variable_get("@#{reflection.name}")
            if !association.nil? && (new_record? || association.new_record? || association["#{reflection.primary_key_name}"] != id)
              association["#{reflection.primary_key_name}"] = id
              association.save(true)
            end
          EOF
        end

        association_accessor_methods_big_record(reflection, HasOneAssociation)
        association_constructor_method_big_record(:build,  reflection, HasOneAssociation)
        association_constructor_method_big_record(:create, reflection, HasOneAssociation)

        configure_dependency_for_has_one(reflection)

        # deprecated api
#        deprecated_has_association_method(reflection.name)
#        deprecated_association_comparison_method(reflection.name, reflection.class_name)
      end

      alias_method :has_one_bigrecord, :has_one_big_record

      # Adds the following methods for retrieval and query for a single associated object that this object holds an id to.
      # +association+ is replaced with the symbol passed as the first argument, so
      # <tt>belongs_to :author</tt> would add among others <tt>author.nil?</tt>.
      # * <tt>association(force_reload = false)</tt> - returns the associated object. Nil is returned if none is found.
      # * <tt>association=(associate)</tt> - assigns the associate object, extracts the primary key, and sets it as the foreign key.
      # * <tt>association.nil?</tt> - returns true if there is no associated object.
      # * <tt>build_association(attributes = {})</tt> - returns a new object of the associated type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key but has not yet been saved.
      # * <tt>create_association(attributes = {})</tt> - returns a new object of the associated type that has been instantiated
      #   with +attributes+ and linked to this object through a foreign key and that has already been saved (if it passed the validation).
      #
      # Example: A Post class declares <tt>belongs_to :author</tt>, which will add:
      # * <tt>Post#author</tt> (similar to <tt>Author.find(author_id)</tt>)
      # * <tt>Post#author=(author)</tt> (similar to <tt>post.author_id = author.id</tt>)
      # * <tt>Post#author?</tt> (similar to <tt>post.author == some_author</tt>)
      # * <tt>Post#author.nil?</tt>
      # * <tt>Post#build_author</tt> (similar to <tt>post.author = Author.new</tt>)
      # * <tt>Post#create_author</tt> (similar to <tt>post.author = Author.new; post.author.save; post.author</tt>)
      # The declaration can also include an options hash to specialize the behavior of the association.
      #
      # Options are:
      # * <tt>:class_name</tt>  - specify the class name of the association. Use it only if that name can't be inferred
      #   from the association name. So <tt>has_one :author</tt> will by default be linked to the +Author+ class, but
      #   if the real class name is +Person+, you'll have to specify it with this option.
      # * <tt>:conditions</tt>  - specify the conditions that the associated object must meet in order to be included as a "WHERE"
      #   sql fragment, such as "authorized = 1".
      # * <tt>:order</tt>       - specify the order from which the associated object will be picked at the top. Specified as
      #   an "ORDER BY" sql fragment, such as "last_name, first_name DESC"
      # * <tt>:foreign_key</tt> - specify the foreign key used for the association. By default this is guessed to be the name
      #   of the associated class in lower-case and "_id" suffixed. So a +Person+ class that makes a belongs_to association to a
      #   +Boss+ class will use "boss_id" as the default foreign_key.
      # * <tt>:counter_cache</tt> - caches the number of belonging objects on the associate class through use of increment_counter
      #   and decrement_counter. The counter cache is incremented when an object of this class is created and decremented when it's
      #   destroyed. This requires that a column named "#{table_name}_count" (such as comments_count for a belonging Comment class)
      #   is used on the associate class (such as a Post class). You can also specify a custom counter cache column by given that
      #   name instead of a true/false value to this option (e.g., <tt>:counter_cache => :my_custom_counter</tt>.)
      # * <tt>:include</tt>  - specify second-order associations that should be eager loaded when this object is loaded.
      # * <tt>:polymorphic</tt> - specify this association is a polymorphic association by passing true.
      #
      # Option examples:
      #   belongs_to :firm, :foreign_key => "client_of"
      #   belongs_to :author, :class_name => "Person", :foreign_key => "author_id"
      #   belongs_to :valid_coupon, :class_name => "Coupon", :foreign_key => "coupon_id",
      #              :conditions => 'discounts > #{payments_count}'
      #   belongs_to :attachable, :polymorphic => true
      def belongs_to_big_record(association_id, options = {})
        if options.include?(:class_name) && !options.include?(:foreign_key)
          ::ActiveSupport::Deprecation.warn(
          "The inferred foreign_key name will change in Rails 2.0 to use the association name instead of its class name when they differ.  When using :class_name in belongs_to, use the :foreign_key option to explicitly set the key name to avoid problems in the transition.",
          caller)
        end

        reflection = create_belongs_to_big_record_reflection(association_id, options)

        if reflection.options[:polymorphic]
          association_accessor_methods_big_record(reflection, BelongsToPolymorphicAssociation)

          module_eval do
            before_save <<-EOF
              association = instance_variable_get("@#{reflection.name}")
              if association && association.target
                if association.new_record?
                  association.save(true)
                end

                if association.updated?
                  self["#{reflection.primary_key_name}"] = association.id
                  self["#{reflection.options[:foreign_type]}"] = association.class.base_class.name.to_s
                end
              end
            EOF
          end
        else
          association_accessor_methods_big_record(reflection, BelongsToAssociation)
          association_constructor_method_big_record(:build,  reflection, BelongsToAssociation)
          association_constructor_method_big_record(:create, reflection, BelongsToAssociation)

          module_eval do
            before_save <<-EOF
              association = instance_variable_get("@#{reflection.name}")
              if !association.nil?
                if association.new_record?
                  association.save(true)
                end

                if association.updated?
                  self["#{reflection.primary_key_name}"] = association.id
                end
              end
            EOF
          end

          # deprecated api
#          deprecated_has_association_method(reflection.name)
#          deprecated_association_comparison_method(reflection.name, reflection.class_name)
        end

        if options[:counter_cache]
          cache_column = options[:counter_cache] == true ?
            "#{self.to_s.underscore.pluralize}_count" :
            options[:counter_cache]

          module_eval(
            "after_create '#{reflection.name}.class.increment_counter(\"#{cache_column}\", #{reflection.primary_key_name})" +
            " unless #{reflection.name}.nil?'"
          )

          module_eval(
            "before_destroy '#{reflection.name}.class.decrement_counter(\"#{cache_column}\", #{reflection.primary_key_name})" +
            " unless #{reflection.name}.nil?'"
          )
        end
      end

      alias_method :belongs_to_bigrecord, :belongs_to_big_record

      def belongs_to_many(association_id, options = {})
        if options.include?(:class_name) && !options.include?(:foreign_key)
          ::ActiveSupport::Deprecation.warn(
          "The inferred foreign_key name will change in Rails 2.0 to use the association name instead of its class name when they differ.  When using :class_name in belongs_to, use the :foreign_key option to explicitly set the key name to avoid problems in the transition.",
          caller)
        end

        reflection = create_belongs_to_many_reflection(association_id, options)

        association_accessor_methods_big_record(reflection, BelongsToManyAssociation)
        association_constructor_method_big_record(:build,  reflection, BelongsToManyAssociation)
        association_constructor_method_big_record(:create, reflection, BelongsToManyAssociation)

        module_eval do
          before_save <<-EOF
            association = instance_variable_get("@#{reflection.name}")
            if !association.nil?
              association.each do |r|
                r.save(true) if r.new_record?
              end

              if association.updated?
                self["#{reflection.primary_key_name}"] = association.collect{|r| r.id}
              end
            end
          EOF
        end

      end

      # Associates two classes via an intermediate join table.  Unless the join table is explicitly specified as
      # an option, it is guessed using the lexical order of the class names. So a join between Developer and Project
      # will give the default join table name of "developers_projects" because "D" outranks "P".  Note that this precedence
      # is calculated using the <tt><</tt> operator for <tt>String</tt>.  This means that if the strings are of different lengths,
      # and the strings are equal when compared up to the shortest length, then the longer string is considered of higher
      # lexical precedence than the shorter one.  For example, one would expect the tables <tt>paper_boxes</tt> and <tt>papers</tt>
      # to generate a join table name of <tt>papers_paper_boxes</tt> because of the length of the name <tt>paper_boxes</tt>,
      # but it in fact generates a join table name of <tt>paper_boxes_papers</tt>.  Be aware of this caveat, and use the
      # custom <tt>join_table</tt> option if you need to.
      #
      # Deprecated: Any additional fields added to the join table will be placed as attributes when pulling records out through
      # has_and_belongs_to_many associations. Records returned from join tables with additional attributes will be marked as
      # ReadOnly (because we can't save changes to the additional attrbutes). It's strongly recommended that you upgrade any
      # associations with attributes to a real join model (see introduction).
      #
      # Adds the following methods for retrieval and query.
      # +collection+ is replaced with the symbol passed as the first argument, so
      # <tt>has_and_belongs_to_many :categories</tt> would add among others <tt>categories.empty?</tt>.
      # * <tt>collection(force_reload = false)</tt> - returns an array of all the associated objects.
      #   An empty array is returned if none is found.
      # * <tt>collection<<(object, ...)</tt> - adds one or more objects to the collection by creating associations in the join table
      #   (collection.push and collection.concat are aliases to this method).
      # * <tt>collection.push_with_attributes(object, join_attributes)</tt> - adds one to the collection by creating an association in the join table that
      #   also holds the attributes from <tt>join_attributes</tt> (should be a hash with the column names as keys). This can be used to have additional
      #   attributes on the join, which will be injected into the associated objects when they are retrieved through the collection.
      #   (collection.concat_with_attributes is an alias to this method). This method is now deprecated.
      # * <tt>collection.delete(object, ...)</tt> - removes one or more objects from the collection by removing their associations from the join table.
      #   This does not destroy the objects.
      # * <tt>collection=objects</tt> - replaces the collections content by deleting and adding objects as appropriate.
      # * <tt>collection_singular_ids</tt> - returns an array of the associated objects ids
      # * <tt>collection_singular_ids=ids</tt> - replace the collection by the objects identified by the primary keys in +ids+
      # * <tt>collection.clear</tt> - removes every object from the collection. This does not destroy the objects.
      # * <tt>collection.empty?</tt> - returns true if there are no associated objects.
      # * <tt>collection.size</tt> - returns the number of associated objects.
      # * <tt>collection.find(id)</tt> - finds an associated object responding to the +id+ and that
      #   meets the condition that it has to be associated with this object.
      # * <tt>collection.build(attributes = {})</tt> - returns a new object of the collection type that has been instantiated
      #   with +attributes+ and linked to this object through the join table but has not yet been saved.
      # * <tt>collection.create(attributes = {})</tt> - returns a new object of the collection type that has been instantiated
      #   with +attributes+ and linked to this object through the join table and that has already been saved (if it passed the validation).
      #
      # Example: An Developer class declares <tt>has_and_belongs_to_many :projects</tt>, which will add:
      # * <tt>Developer#projects</tt>
      # * <tt>Developer#projects<<</tt>
      # * <tt>Developer#projects.delete</tt>
      # * <tt>Developer#projects=</tt>
      # * <tt>Developer#project_ids</tt>
      # * <tt>Developer#project_ids=</tt>
      # * <tt>Developer#projects.clear</tt>
      # * <tt>Developer#projects.empty?</tt>
      # * <tt>Developer#projects.size</tt>
      # * <tt>Developer#projects.find(id)</tt>
      # * <tt>Developer#projects.build</tt> (similar to <tt>Project.new("project_id" => id)</tt>)
      # * <tt>Developer#projects.create</tt> (similar to <tt>c = Project.new("project_id" => id); c.save; c</tt>)
      # The declaration may include an options hash to specialize the behavior of the association.
      #
      # Options are:
      # * <tt>:class_name</tt> - specify the class name of the association. Use it only if that name can't be inferred
      #   from the association name. So <tt>has_and_belongs_to_many :projects</tt> will by default be linked to the
      #   +Project+ class, but if the real class name is +SuperProject+, you'll have to specify it with this option.
      # * <tt>:join_table</tt> - specify the name of the join table if the default based on lexical order isn't what you want.
      #   WARNING: If you're overwriting the table name of either class, the table_name method MUST be declared underneath any
      #   has_and_belongs_to_many declaration in order to work.
      # * <tt>:foreign_key</tt> - specify the foreign key used for the association. By default this is guessed to be the name
      #   of this class in lower-case and "_id" suffixed. So a +Person+ class that makes a has_and_belongs_to_many association
      #   will use "person_id" as the default foreign_key.
      # * <tt>:association_foreign_key</tt> - specify the association foreign key used for the association. By default this is
      #   guessed to be the name of the associated class in lower-case and "_id" suffixed. So if the associated class is +Project+,
      #   the has_and_belongs_to_many association will use "project_id" as the default association foreign_key.
      # * <tt>:conditions</tt>  - specify the conditions that the associated object must meet in order to be included as a "WHERE"
      #   sql fragment, such as "authorized = 1".
      # * <tt>:order</tt> - specify the order in which the associated objects are returned as a "ORDER BY" sql fragment, such as "last_name, first_name DESC"
      # * <tt>:uniq</tt> - if set to true, duplicate associated objects will be ignored by accessors and query methods
      # * <tt>:finder_sql</tt> - overwrite the default generated SQL used to fetch the association with a manual one
      # * <tt>:delete_sql</tt> - overwrite the default generated SQL used to remove links between the associated
      #   classes with a manual one
      # * <tt>:insert_sql</tt> - overwrite the default generated SQL used to add links between the associated classes
      #   with a manual one
      # * <tt>:extend</tt>  - anonymous module for extending the proxy, see "Association extensions".
      # * <tt>:include</tt>  - specify second-order associations that should be eager loaded when the collection is loaded.
      # * <tt>:group</tt>: An attribute name by which the result should be grouped. Uses the GROUP BY SQL-clause.
      # * <tt>:limit</tt>: An integer determining the limit on the number of rows that should be returned.
      # * <tt>:offset</tt>: An integer determining the offset from where the rows should be fetched. So at 5, it would skip the first 4 rows.
      # * <tt>:select</tt>: By default, this is * as in SELECT * FROM, but can be changed if you for example want to do a join, but not
      #   include the joined columns.
      #
      # Option examples:
      #   has_and_belongs_to_many :projects
      #   has_and_belongs_to_many :projects, :include => [ :milestones, :manager ]
      #   has_and_belongs_to_many :nations, :class_name => "Country"
      #   has_and_belongs_to_many :categories, :join_table => "prods_cats"
      #   has_and_belongs_to_many :active_projects, :join_table => 'developers_projects', :delete_sql =>
      #   'DELETE FROM developers_projects WHERE active=1 AND developer_id = #{id} AND project_id = #{record.id}'
      def has_and_belongs_to_many_big_records(association_id, options = {}, &extension)
        reflection = create_has_and_belongs_to_many_big_records_reflection(association_id, options, &extension)

        collection_accessor_methods(reflection, HasAndBelongsToManyAssociation)

        # Don't use a before_destroy callback since users' before_destroy
        # callbacks will be executed after the association is wiped out.
        old_method = "destroy_without_habtm_shim_for_#{reflection.name}"
        class_eval <<-end_eval
          alias_method :#{old_method}, :destroy_without_callbacks
          def destroy_without_callbacks
            #{reflection.name}.clear
            #{old_method}
          end
        end_eval

        add_association_callbacks(reflection.name, options)

        # deprecated api
#        deprecated_collection_count_method(reflection.name)
#        deprecated_add_association_relation(reflection.name)
#        deprecated_remove_association_relation(reflection.name)
#        deprecated_has_collection_method(reflection.name)
      end

      alias_method :has_and_belongs_to_many_bigrecords, :has_and_belongs_to_many_big_records

      private
        def association_accessor_methods_big_record(reflection, association_proxy_class)
          define_method(reflection.name) do |*params|
            force_reload = params.first unless params.empty?
            association = instance_variable_get("@#{reflection.name}")

            if association.nil? || force_reload
              association = association_proxy_class.new(self, reflection)
              retval = association.reload
              if retval.nil? and association_proxy_class == BelongsToAssociation
                instance_variable_set("@#{reflection.name}", nil)
                return nil
              end
              instance_variable_set("@#{reflection.name}", association)
            end

            association.target.nil? ? nil : association
          end

          define_method("#{reflection.name}=") do |new_value|
            association = instance_variable_get("@#{reflection.name}")
            if association.nil?
              association = association_proxy_class.new(self, reflection)
            end

            association.replace(new_value)

            unless new_value.nil?
              instance_variable_set("@#{reflection.name}", association)
            else
              instance_variable_set("@#{reflection.name}", nil)
              return nil
            end

            association
          end

          define_method("set_#{reflection.name}_target") do |target|
            return if target.nil? and association_proxy_class == BelongsToAssociation
            association = association_proxy_class.new(self, reflection)
            association.target = target
            instance_variable_set("@#{reflection.name}", association)
          end
        end

        def association_constructor_method_big_record(constructor, reflection, association_proxy_class)
          define_method("#{constructor}_#{reflection.name}") do |*params|
            attributees      = params.first unless params.empty?
            replace_existing = params[1].nil? ? true : params[1]
            association      = instance_variable_get("@#{reflection.name}")

            if association.nil?
              association = association_proxy_class.new(self, reflection)
              instance_variable_set("@#{reflection.name}", association)
            end

            if association_proxy_class == HasOneAssociation
              association.send(constructor, attributees, replace_existing)
            else
              association.send(constructor, attributees)
            end
          end
        end

        def create_has_many_big_records_reflection(association_id, options, &extension)
          options.assert_valid_keys(
            :class_name, :table_name, :foreign_key,
            :exclusively_dependent, :dependent,
            :select, :conditions, :include, :order, :group, :limit, :offset,
            :as, :through, :source, :source_type,
            :uniq,
            :finder_sql, :counter_sql,
            :before_add, :after_add, :before_remove, :after_remove,
            :extend
          )

          options[:extend] = create_extension_module(association_id, extension) if block_given?

          create_reflection_big_record(:has_many_big_records, association_id, options, self)
        end

        def create_has_one_big_record_reflection(association_id, options)
          options.assert_valid_keys(
            :class_name, :foreign_key, :remote, :conditions, :order, :include, :dependent, :counter_cache, :extend, :as
          )

          create_reflection_big_record(:has_one_big_record, association_id, options, self)
        end

        def create_belongs_to_big_record_reflection(association_id, options)
          options.assert_valid_keys(
            :class_name, :foreign_key, :foreign_type, :remote, :conditions, :order, :include, :dependent,
            :counter_cache, :extend, :polymorphic
          )

          reflection = create_reflection_big_record(:belongs_to_big_record, association_id, options, self)

          if options[:polymorphic]
            reflection.options[:foreign_type] ||= reflection.class_name.underscore + "_type"
          end

          reflection
        end

        def create_belongs_to_many_reflection(association_id, options)
          options.assert_valid_keys(
            :class_name, :foreign_key, :foreign_type, :remote, :conditions, :order, :include, :dependent, :extend, :cache
          )

          create_reflection_big_record(:belongs_to_many, association_id, options, self)
        end

        def create_has_and_belongs_to_many_big_records_reflection(association_id, options, &extension)
          options.assert_valid_keys(
            :class_name, :table_name, :join_table, :foreign_key, :association_foreign_key,
            :select, :conditions, :include, :order, :group, :limit, :offset,
            :uniq,
            :finder_sql, :delete_sql, :insert_sql,
            :before_add, :after_add, :before_remove, :after_remove,
            :extend
          )

          options[:extend] = create_extension_module(association_id, extension) if block_given?

          reflection = create_reflection_big_record(:has_and_belongs_to_many_big_records, association_id, options, self)

          reflection.options[:join_table] ||= join_table_name(undecorated_table_name(self.to_s), undecorated_table_name(reflection.class_name))

          reflection
        end
    end
  end
end
