defmodule Proto.Mob.Acceptor do
  use GenServer
  require Logger

  @upstream_address 'chat.protohackers.com'
  @upstream_port 16963
  @tonys_address "7YWHMfk9JZe0LM0g1ZauHuiSxhI"
  @address_regex Regex.compile!("(?<address>^7[0-9A-Za-z]{25,34}$)")

  def start_link(args) do
    GenServer.start(__MODULE__, args)
  end

  def init(state) do
    state = Map.put(state, :prices, %{})
    {:ok, state, {:continue, :connect_upstream}}
  end

  def handle_continue(:connect_upstream, %{socket: client_socket} = state) do
    {:ok, upstream_ip} = :inet.getaddr(@upstream_address, :inet)

    {:ok, upstream_socket} =
      :gen_tcp.connect(upstream_ip, @upstream_port, [
        :binary,
        {:active, false},
        {:packet, :line},
        {:recbuf, :math.pow(2, 16) |> Kernel.floor()}
      ])

    state = Map.put(state, :upstream_socket, upstream_socket)

    active(client_socket)
    active(upstream_socket)

    {:noreply, state}
  end

  def handle_info(
        {:tcp, socket, line},
        %{socket: client_socket, upstream_socket: upstream_socket} = state
      ) do
    cond do
      socket == client_socket ->
        line = maybe_rewrite_boguscoin_address(line)
        :ok = :gen_tcp.send(upstream_socket, line)
        active(client_socket)
        {:noreply, state}

      socket == upstream_socket ->
        line = maybe_rewrite_boguscoin_address(line)
        :ok = :gen_tcp.send(client_socket, line)
        active(upstream_socket)
        {:noreply, state}
    end
  end

  defp maybe_rewrite_boguscoin_address(line) do
    line
    |> String.split()
    |> Enum.filter(fn s ->
      Regex.match?(@address_regex, s)
    end)
    |> Enum.reduce(line, fn matcher, line ->
      String.replace(line, matcher, @tonys_address)
    end)
  end

  defp active(socket) do
    :inet.setopts(socket, [{:active, :once}])
  end
end
