class <%= class_name %> < BigRecord::Base

<% attributes.each do |attribute| -%>
  column :<%= attribute.name %>,<%= " " * (20 - attribute.name.length) %>:<%= attribute.type %>
<% end -%>

end
