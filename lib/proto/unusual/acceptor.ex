defmodule Proto.Unusual.Acceptor do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(state) do
    state = Map.put(state, :db, %{"version" => "kendb 1.0"})
    {:ok, state, {:continue, :start}}
  end

  @impl true
  def handle_continue(:start, %{port: port} = state) do
    {:ok, fly_global_services_ip} = :inet.getaddr('fly-global-services', :inet)

    {:ok, socket} =
      :gen_udp.open(port, [
        {:inet_backend, :socket},
        :binary,
        {:active, :once},
        {:reuseaddr, true},
        {:ip, fly_global_services_ip}
      ])

    Logger.debug(
      "Proto.Unusual.Acceptor listening for UDP on #{inspect(fly_global_services_ip)}:#{port}"
    )

    state = Map.put(state, :socket, socket)

    {:noreply, state}
  end

  @impl true
  def handle_info({:udp, socket, ip, port, packet}, state) do
    if String.contains?(packet, "=") do
      [k, v] = String.split(packet, "=", parts: 2)

      if k == "version" do
        :ok = :inet.setopts(socket, [{:active, :once}])
        {:noreply, state}
      else
        state = Kernel.put_in(state, [:db, k], v)
        :ok = :inet.setopts(socket, [{:active, :once}])
        {:noreply, state}
      end
    else
      k = packet
      v = Kernel.get_in(state, [:db, k])
      reply = [k, "=", v]

      :gen_udp.send(socket, {ip, port}, reply)

      :ok = :inet.setopts(socket, [{:active, :once}])
      {:noreply, state}
    end
  end
end
