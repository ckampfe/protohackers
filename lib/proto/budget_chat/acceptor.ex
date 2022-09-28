defmodule Proto.BudgetChat.Acceptor do
  require Logger
  alias Phoenix.PubSub

  @behaviour :gen_statem

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :transient,
      shutdown: 500
    }
  end

  def start_link(args) do
    :gen_statem.start_link(__MODULE__, args, [])
  end

  @impl true
  def init(data) do
    {:ok, :initial, data, [{:next_event, :internal, :ask_for_username}]}
  end

  @impl true
  def callback_mode() do
    :handle_event_function
  end

  @impl true
  def handle_event(:internal, :ask_for_username = event, :initial = state, data) do
    Logger.debug(data: data, state: state, event: event)

    :ok = :gen_tcp.send(data[:socket], "username?\n")

    :ok = :inet.setopts(data[:socket], [{:active, :once}])

    {:next_state, :waiting_for_username, data}
  end

  @impl true
  def handle_event(:info, {:tcp, socket, line} = event, :waiting_for_username = state, data) do
    Logger.debug(user: data[:user], state: state, event: event)

    if is_valid_username?(line) do
      username = String.trim(line)

      data = Map.put(data, :user, username)

      :ok = Proto.ChatTableManager.register_user(data[:user])

      {:next_state, :joined, data, [{:next_event, :internal, :announce}]}
    else
      :ok = :gen_tcp.send(socket, "invalid username\n")
      :ok = :gen_tcp.close(socket)
      :stop
    end
  end

  @impl true
  def handle_event(:internal, :announce = event, :joined = state, data) do
    Logger.debug(user: data[:user], state: state, event: event)

    PubSub.broadcast!(:proto_pubsub, "user:join", {:user_new, data[:user]})

    {:keep_state, data, [{:next_event, :internal, :room_membership}]}
  end

  @impl true
  def handle_event(:internal, :room_membership = event, :joined = state, data) do
    Logger.debug(user: data[:user], state: state, event: event)

    other_users =
      Proto.ChatTableManager.users()
      |> Enum.filter(fn user -> user != data[:user] end)
      |> Enum.join(", ")

    :ok = :gen_tcp.send(data[:socket], "* users: #{other_users}\n")

    {:keep_state, data, [{:next_event, :internal, :subscribe}]}
  end

  @impl true
  def handle_event(:internal, :subscribe = event, :joined = state, data) do
    Logger.debug(user: data[:user], state: state, event: event)

    PubSub.subscribe(:proto_pubsub, "user:join")
    PubSub.subscribe(:proto_pubsub, "chat:new")
    PubSub.subscribe(:proto_pubsub, "user:leave")

    :ok = :inet.setopts(data[:socket], [{:active, :once}])

    {:next_state, :chat_loop, data}
  end

  @impl true
  def handle_event(:info, {:tcp, socket, line} = event, :chat_loop = state, data) do
    Logger.debug(user: data[:user], state: state, event: event)

    user = data[:user]

    line = String.slice(line, 0..999)

    message = "[#{user}] #{line}"

    PubSub.broadcast!(:proto_pubsub, "chat:new", {:chat_message, user, message})

    :inet.setopts(socket, [{:active, :once}])

    :keep_state_and_data
  end

  @impl true
  def handle_event(:info, {:user_new, user} = event, state, data) do
    Logger.debug(user: data[:user], state: state, event: event)

    if data[:user] != user do
      :ok = :gen_tcp.send(data[:socket], "* new user joined: #{user}\n")
    end

    :keep_state_and_data
  end

  @impl true
  def handle_event(:info, {:chat_message, user, message} = event, state, data) do
    Logger.debug(user: data[:user], state: state, event: event)

    if data[:user] != user do
      :ok = :gen_tcp.send(data[:socket], message)
    end

    :keep_state_and_data
  end

  @impl true
  def handle_event(:info, {:user_leave, user} = event, state, data) do
    Logger.debug(user: data[:user], state: state, event: event)

    if data[:user] != user do
      :ok = :gen_tcp.send(data[:socket], "* #{user} left\n")
    end

    :keep_state_and_data
  end

  @impl true
  def handle_event(:info, {:tcp_closed, _socket} = event, state, data) do
    Logger.debug(user: data[:user], state: state, event: event)

    PubSub.unsubscribe(:proto_pubsub, "user:leave")

    if data[:user] do
      Proto.ChatTableManager.deregister_user(data[:user])
      PubSub.broadcast!(:proto_pubsub, "user:leave", {:user_leave, data[:user]})
    end

    :stop
  end

  @impl true
  def handle_event(:info, {:tcp_error, _socket, _reason} = event, state, data) do
    Logger.debug(user: data[:user], state: state, event: event)

    PubSub.unsubscribe(:proto_pubsub, "user:leave")

    if data[:user] do
      Proto.ChatTableManager.deregister_user(data[:user])
      PubSub.broadcast!(:proto_pubsub, "user:leave", {:user_leave, data[:user]})
    end

    :stop
  end

  @impl true
  def terminate(reason, state, data) do
    Logger.debug(data: data, state: state, reason: reason)
    :ok
  end

  def is_valid_username?(s) do
    String.length(s) >= 1 && String.length(s) <= 16 && is_alphanumeric?(s)
  end

  def is_alphanumeric?(s) do
    cl = String.to_charlist(s)
    :io_lib.printable_latin1_list(cl)
  end
end
