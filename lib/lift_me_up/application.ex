defmodule LiftMeUp.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do

    children = [
      LiftMeUp,
      Driver,
      Poller
    ]

    node_name = get_my_ip()
    |> :inet.ntoa
    |> to_string
    |> (fn ip -> "elevator@#{ip}" end).()
    |> String.to_atom

    {:ok, _} = Node.start(node_name, :longnames, 1000)
    Node.set_cookie(:safarikjeks)
    opts = [strategy: :one_for_one, name: LiftMeUp.Supervisor]
    Supervisor.start_link(children, opts)
  end


  def get_my_ip do
    {:ok, socket} = :gen_udp.open(6790, [active: false, broadcast: true])
    :ok = :gen_udp.send(socket, {255,255,255,255}, 6790, "test packet")
    ip = case :gen_udp.recv(socket, 100, 1000) do
      {:ok, {ip, _port, _data}} -> ip
      {:error, _} -> {:error, :could_not_get_ip}
    end
    :gen_udp.close(socket)
    ip
  end

end
