defmodule Proto.GenListener do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(state) do
    state = Map.put(state, :socks, [])
    {:ok, state, {:continue, :listen}}
  end

  def handle_continue(:listen, state) do
    Logger.debug(
      "Proto.GenListener listening for #{inspect(state[:acceptor])} on #{state[:port]}"
    )

    {:ok, lsock} = :gen_tcp.listen(state[:port], state[:options])

    state = Map.put(state, :lsock, lsock)

    {:noreply, state, {:continue, :accept}}
  end

  def handle_continue(:accept, state) do
    {:ok, socket} = :gen_tcp.accept(state[:lsock])

    {:ok, child} = Proto.GenSupervisor.start_child(state[:supervisor], state[:acceptor], socket)

    :gen_tcp.controlling_process(socket, child)

    {:noreply, state, {:continue, :accept}}
  end
end
