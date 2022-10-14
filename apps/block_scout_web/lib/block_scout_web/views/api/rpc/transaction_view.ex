defmodule BlockScoutWeb.API.RPC.TransactionView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.API.RPC.ContractController, only: [to_smart_contract_raw: 1]

  alias Explorer.Chain.Transaction
  alias BlockScoutWeb.API.RPC.RPCView

  def render("gettxinfo.json", %{
        transaction: transaction,
        block_height: block_height,
        logs: logs,
        next_page_params: next_page_params
      }) do
    data = prepare_transaction(transaction, block_height, logs, next_page_params)
    RPCView.render("show.json", data: data)
  end

  def render("gettxcosmosinfo.json", %{
        transaction: transaction,
        block_height: block_height,
        logs: logs
      }) do
    data = prepare_transaction_cosmos(transaction, block_height, logs)
    RPCView.render("show.json", data: data)
  end

  def render("gettxreceiptstatus.json", %{status: status}) do
    prepared_status = prepare_tx_receipt_status(status)
    RPCView.render("show.json", data: %{"status" => prepared_status})
  end

  def render("getstatus.json", %{error: error}) do
    RPCView.render("show.json", data: prepare_error(error))
  end

  def render("error.json", assigns) do
    RPCView.render("error.json", assigns)
  end

  defp prepare_tx_receipt_status(""), do: ""

  defp prepare_tx_receipt_status(nil), do: ""

  defp prepare_tx_receipt_status(:ok), do: "1"

  defp prepare_tx_receipt_status(_), do: "0"

  defp prepare_error("") do
    %{
      "isError" => "0",
      "errDescription" => ""
    }
  end

  defp prepare_error(error) when is_binary(error) do
    %{
      "isError" => "1",
      "errDescription" => error
    }
  end

  defp prepare_error(error) when is_atom(error) do
    %{
      "isError" => "1",
      "errDescription" => error |> Atom.to_string() |> String.replace("_", " ")
    }
  end

  defp prepare_transaction(transaction, block_height, logs, next_page_params) do
    %{
      "hash" => "#{transaction.hash}",
      "timeStamp" => "#{DateTime.to_unix(transaction.block.timestamp)}",
      "blockNumber" => "#{transaction.block_number}",
      "confirmations" => "#{block_height - transaction.block_number}",
      "success" => if(transaction.status == :ok, do: true, else: false),
      "from" => "#{transaction.from_address_hash}",
      "to" => "#{transaction.to_address_hash}",
      "value" => "#{transaction.value.value}",
      "input" => "#{transaction.input}",
      "gasLimit" => "#{transaction.gas}",
      "gasUsed" => "#{transaction.gas_used}",
      "gasPrice" => "#{transaction.gas_price.value}",
      "logs" => Enum.map(logs, &prepare_log/1),
      "revertReason" => "#{transaction.revert_reason}",
      "next_page_params" => next_page_params
    }
  end

  defp prepare_transaction_cosmos(transaction, block_height, logs) do
    %{
      "blockHeight" => transaction.block_number,
      "blockHash" => "#{transaction.block.hash}",
      "blockTime" => transaction.block.timestamp,
      "hash" => "#{transaction.hash}",
      "cosmosHash" => "#{transaction.cosmos_hash}",
      "confirmations" => block_height - transaction.block_number,
      "success" => if(transaction.status == :ok, do: true, else: false),
      "error" => "#{transaction.error}",
      "from" => "#{transaction.from_address_hash}",
      "to" => "#{transaction.to_address_hash}",
      "value" => transaction.value.value,
      "input" => "#{transaction.input}",
      "decodedInput" =>
        decoded_input_transaction_data(transaction.input, transaction.to_address_hash, transaction.hash),
      "gasLimit" => transaction.gas,
      "gasUsed" => transaction.gas_used,
      "gasPrice" => transaction.gas_price.value,
      "cumulativeGasUsed" => transaction.cumulative_gas_used,
      "index" => transaction.index,
      "createdContractCodeIndexedAt" => transaction.created_contract_code_indexed_at,
      "nonce" => transaction.nonce,
      "r" => transaction.r,
      "s" => transaction.s,
      "v" => transaction.v,
      "maxPriorityFeePerGas" => parse_gas_value(transaction.max_priority_fee_per_gas),
      "maxFeePerGas" => parse_gas_value(transaction.max_fee_per_gas),
      "type" => transaction.type,
      "tokenTransfers" => Enum.map(transaction.token_transfers, &prepare_token_transfer/1),
      "logs" => Enum.map(logs, &prepare_log/1),
      "revertReason" => "#{transaction.revert_reason}"
    }
  end

  defp parse_gas_value(gas_field) do
    case gas_field do
      nil ->
        nil
      _ ->
        gas_field.value
    end
  end

  defp prepare_token_transfer(token_transfer) do
    %{
      "amount" => "#{token_transfer.amount}",
      "logIndex" => "#{token_transfer.log_index}",
      "fromAddress" => "#{token_transfer.from_address}",
      "fromAddressName" => prepare_address_name(token_transfer.from_address.names),
      "toAddress" => "#{token_transfer.to_address}",
      "toAddressName" => prepare_address_name(token_transfer.to_address.names),
      "tokenContractAddress" => "#{token_transfer.token_contract_address}",
      "tokenName" => "#{token_transfer.token.name}",
      "tokenSymbol" => "#{token_transfer.token.symbol}",
      "decimals" => "#{token_transfer.token.decimals}"
    }
  end

  defp prepare_address_name(address_names) do
    case address_names do
      [_|_] ->
        Enum.at(address_names, 0).name
      _ ->
        ""
    end
  end

  defp prepare_log(log) do
    %{
      "address" => "#{log.address_hash}",
      "topics" => get_topics(log) |> Enum.filter(fn log -> is_nil(log) == false end),
      "data" => "#{log.data}",
      "index" => "#{log.index}"
    }
  end

  defp get_topics(log) do
    [log.first_topic, log.second_topic, log.third_topic, log.fourth_topic]
  end

  defp decoded_input_transaction_data(input, to_address_hash, transaction_hash) do
    with {:contract, {:ok, contract}} <- to_smart_contract_raw(to_address_hash) do
      case Transaction.decoded_input_data(input, contract, transaction_hash) do
        {:error, :contract_not_verified, _} ->
          "Contract source code not verified"
        {:error, :could_not_decode} ->
          "Could not decode input data"
        output ->
          output
      end
    else
      {:contract, :not_found} ->
        "Contract source code not found"
    end
  end
end
