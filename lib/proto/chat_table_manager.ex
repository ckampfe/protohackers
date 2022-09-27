defmodule Proto.ChatTableManager do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(state) do
    {:ok, state, {:continue, :create_table}}
  end

  def handle_continue(:create_table, state) do
    :ets.new(:chat_users, [:set, :public, :named_table])
    {:noreply, state}
  end

  def register_user(username) do
    true = :ets.insert(:chat_users, {username, nil})
    :ok
  end

  def deregister_user(username) do
    :ets.delete_object(:chat_users, {username, nil})
  end

  def users() do
    :ets.tab2list(:chat_users)
    |> Enum.map(fn {user, _} -> user end)
  end
end
