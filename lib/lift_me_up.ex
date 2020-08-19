defmodule LiftMeUp do
  use GenServer
  require Logger
  require Order

  @ping_rate 1000
  @broadcast_ip {255,255,255,255}
  @broadcast_port 6789

  defstruct [:socket, :timer_ref, :orders]


  ## API


  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end


  def store_order(order = %Order{})do
    GenServer.multi_call(__MODULE__, {:store_order, order})
  end


  def remove_order(order = %Order{}) do
    GenServer.call(__MODULE__, {:remove_order, order})
  end

  def broker_order(order = %Order{type: :cab}) do
    order
    |> Map.put(:owner, Node.self)
    |> store_order
  end

  def broker_order(order = %Order{}) do
    nodes = Node.list [:this, :connected]
    Logger.info("Brokering order #{inspect order} between nodes #{inspect nodes}")

    all_bids = get_bids(order)
    Logger.info("Got bids for #{inspect order}: #{inspect all_bids}")

    [{node, _best_bid}| _bids] = all_bids
    |> List.keysort(1)

    order
    |> Map.put(:owner, node)
    |> store_order
  end

  def enter_floor(floor) when Order.is_floor(floor) do
    Logger.info("Entered Floor: #{floor}")
  end


  ### Helpers


  defp get_bids(order) do
    {bids, _bad_nodes} = GenServer.multi_call(__MODULE__, {:get_bid, order})
    bids
  end


  ### Initialization


  def init([]) do
    initial_state = %LiftMeUp{orders: MapSet.new}
      |> enable_node_monitoring
      |> open_broadcast_socket(@broadcast_port)
      |> start_broadcast_timer

    {:ok, initial_state}
  end


  defp start_broadcast_timer(%LiftMeUp{socket: socket} = state) do
    {:ok, timer_ref} = :timer.apply_interval(@ping_rate, __MODULE__, :send_broadcast, [socket])
    %LiftMeUp{state | timer_ref: timer_ref}
  end


  def send_broadcast(socket) do
    node_name = :erlang.term_to_binary(Node.self)
    :ok = :gen_udp.send(socket, @broadcast_ip, @broadcast_port, node_name)
  end


  defp open_broadcast_socket(%LiftMeUp{socket: nil} = state, port) do
    {:ok, socket} = :gen_udp.open(port, [:binary, broadcast: true, reuseaddr: true] )
    %{state | socket: socket}
  end


  defp enable_node_monitoring(state = %LiftMeUp{}) do
    :ok = :net_kernel.monitor_nodes(true)
    state
  end


  ### Callbacks

  def handle_info({:udp, _ , _ip, _port, msg}, state) do
    new_node = :erlang.binary_to_term(msg)
    nodes = [Node.self | Node.list]

    if new_node not in nodes do
      if Node.connect(new_node) do
        Logger.info("Discovered new node at #{new_node}")
      end
    end

    {:noreply, state}
  end


  def handle_info({:nodedown, node}, state) do
    Logger.warn("Node down at #{node}")
    {:noreply, state}
  end


  def handle_info({:nodeup, node}, state) do
    Logger.info("Node joined at #{node}")
    {:noreply, state}
  end


  def handle_call({:store_order, order}, _from, %{orders: orders} = state) do
    Logger.info("Storing order #{inspect order}")
    {
      :reply,
      :ok,
      %{state | orders: MapSet.put(orders, order)
      }
    }
  end


  def handle_call({:remove_order, order}, _from, %{orders: orders} = state) do
    {
      :reply,
      :ok,
      %{state | orders: MapSet.delete(orders, order)}
    }
  end


  def handle_call({:get_bid, _order}, _from, state) do
    {:reply, 9, state}
  end
end
