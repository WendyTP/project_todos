require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

configure do
  set :erb, :escape_html => true
end

helpers do
  def list_completed?(list)
    todos_total_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_completed?(list)
  end

  def todos_remaining_count(list)
    result = 0
    list[:todos].each do |todo|
      result += 1 if todo[:completed] == false
    end
    result
  end

  def todos_total_count(list)
    list[:todos].size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_completed?(list) }

    incomplete_lists.each { |list| block.call(list, lists.index(list)) }
    complete_lists.each { |list| block.call(list, lists.index(list)) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| block.call(todo) }
    complete_todos.each { |todo| block.call(todo) }
  end
end

before do
  session[:lists] ||= []
end

def load_list(index)
  if index && session[:lists][index]
    list = session[:lists][index]
    return list
  else
    session[:error] = "The specified list was not found."
    redirect "/lists"
  end
end

get "/" do
  redirect "/lists"
end

# View all the lists (list of lists)
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if the list name is invalid.
# Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name].downcase == name.downcase }
    "List name must be unqiue."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View a single list
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  erb :list, layout: :layout
end

# Render an edit-list form for an exisiting todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# Update an exisitng todo list (the name of list)
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete a todo list
post "/lists/:id/delete" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted"
    redirect "/lists"
  end
end

# Return an error message if the todoname is invalid.
# Return nil if name is valid.
def error_for_todo_name(name, list)
  if !(1..100).cover?(name.size)
    "Todo must be between 1 and 100 characters."
  elsif list[:todos].any? { |todo| todo[:name].downcase == name.downcase }
    "Todo name must be unqiue."
  end
end

# assign todo_id to new todo item
def next_todo_id(todos)
max_existing_todo_id = todos.map {|todo| todo[:id]}.max || 0
max_existing_todo_id + 1
end

# Add a todo item to a todo list
post "/lists/:list_id/todos" do
  text = params[:todo].strip
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  error = error_for_todo_name(text, @list)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    todo_id = next_todo_id(@list[:todos])
    @list[:todos] << { id: todo_id, name: text, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo item
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i
  @list[:todos].reject! {|todo| todo[:id] == todo_id}

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been updated"
    redirect "/lists/#{@list_id}"
  end
end

# Update the status of a todo item
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i
  @todo = @list[:todos].find { |todo| todo[:id] == todo_id}
  is_completed = params[:completed] == "true"
  @todo[:completed] = is_completed
  session[:success] = "The todo has been updated"
  redirect "/lists/#{@list_id}"
end

# Mark all todos on a todo list as complete
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @list[:todos].map { |todo| todo[:completed] = true }
  session[:success] = "All todos have been completed."
  redirect "lists/#{@list_id}"
end
