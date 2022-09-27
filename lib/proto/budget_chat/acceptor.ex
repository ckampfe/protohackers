defmodule Proto.BudgetChat.Acceptor do
  use GenServer
  require Logger
  alias Phoenix.PubSub

  def start_link(args) do
    GenServer.start(__MODULE__, args)
  end

  def init(state) do
    state = Map.put(state, :prices, %{})
    {:ok, state, {:continue, :ask_for_name}}
  end

  def handle_continue(:ask_for_name, state) do
    :ok = :gen_tcp.send(state[:socket], "username?\n")
    {:noreply, state, {:continue, :receive_name}}
  end

  def handle_continue(:receive_name, state) do
    case :gen_tcp.recv(state[:socket], 0) do
      {:ok, line} ->
        if is_valid_username?(line) do
          username = String.trim(line)

          state = Map.put(state, :user, username)

          {:noreply, state, {:continue, :subscribe}}
        else
          :gen_tcp.send(state[:socket], "invalid username\n")
          :gen_tcp.close(state[:socket])
          {:stop, :normal, state}
        end

      {:error, e} ->
        Logger.error(inspect(e))
        {:stop, :normal, state}
    end
  end

  def handle_continue(:subscribe, state) do
    previous_users = Proto.ChatTableManager.users() |> Enum.join(", ")

    PubSub.subscribe(:proto_pubsub, "user:join")
    PubSub.subscribe(:proto_pubsub, "chat:new")
    PubSub.subscribe(:proto_pubsub, "user:leave")

    :ok = Proto.ChatTableManager.register_user(state[:user])

    PubSub.broadcast!(:proto_pubsub, "user:join", {:user_new, state[:user]})

    :gen_tcp.send(state[:socket], "* users: #{previous_users}\n")

    {:noreply, state, {:continue, :chat_loop}}
  end

  def handle_continue(:chat_loop, state) do
    case :gen_tcp.recv(state[:socket], 0, 10) do
      {:ok, line} ->
        user = state[:user]
        line = String.slice(line, 0..999)
        message = "[#{user}] #{line}"
        PubSub.broadcast!(:proto_pubsub, "chat:new", {:chat_message, user, message})
        :timer.send_after(100, :chat_loop)
        {:noreply, state}

      {:error, :timeout} ->
        :timer.send_after(100, :chat_loop)
        {:noreply, state}

      {:error, _} ->
        Proto.ChatTableManager.deregister_user(state[:user])
        PubSub.broadcast!(:proto_pubsub, "user:leave", {:user_leave, state[:user]})
        {:stop, :normal, state}
    end
  end

  def handle_info(:chat_loop, state) do
    {:noreply, state, {:continue, :chat_loop}}
  end

  def handle_info({:user_new, user}, state) do
    if state[:user] != user do
      :gen_tcp.send(state[:socket], "* new user joined: #{user}\n")
    end

    {:noreply, state, {:continue, :chat_loop}}
  end

  def handle_info({:chat_message, user, message}, state) do
    if state[:user] != user do
      :gen_tcp.send(state[:socket], message)
    end

    {:noreply, state, {:continue, :chat_loop}}
  end

  def handle_info({:user_leave, user}, state) do
    if state[:user] != user do
      :gen_tcp.send(state[:socket], "* #{user} left\n")
    end

    {:noreply, state, {:continue, :chat_loop}}
  end

  def is_valid_username?(s) do
    String.length(s) >= 1 && String.length(s) <= 16 && is_alphanumeric?(s)
  end

  def is_alphanumeric?(s) do
    cl = String.to_charlist(s)
    :io_lib.printable_latin1_list(cl)
  end
end
