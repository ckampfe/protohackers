defmodule Proto.GenSupervisor do
  use DynamicSupervisor

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: args[:sup_name])
  end

  def init(_init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: []
    )
  end

  def start_child(sup_name, acceptor, socket) do
    DynamicSupervisor.start_child(sup_name, {acceptor, %{socket: socket}})
  end
end
