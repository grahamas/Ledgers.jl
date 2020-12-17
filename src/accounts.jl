abstract type Identifier end

struct AccountId <: Identifier
    value::UUID
end

AccountId() = AccountId(uuid4())

struct AccountNumber
    value::String
end

AccountNumber() = AccountNumber("")

Base.convert(::Type{AccountNumber}, value::String) = AccountNumber(value)

abstract type AbstractAccount{P <: Position} end



struct AccountGroup{A <: AbstractAccount}
    id::AccountId
    number::AccountNumber
    name::String
    isdebit::Bool
    accounts::Dict{AccountId,A}
    subgroups::Dict{AccountId,AccountGroup{A}}
end
id(ag::AccountGroup) = ag.id

function AccountGroup(
        ::Type{A};
        name::String="$(symbol(A)) Accounts",
        number="",
        isdebit=true,
        id=AccountId(),
        parent::Union{Nothing,AccountGroup{A}}=nothing
    ) where {A <: AbstractAccount}
    accounts = Dict{AccountId,A}()
    subgroups = Dict{AccountId,AccountGroup{A}}()
    if parent === nothing
        return AccountGroup{A}(id, number, name, isdebit, accounts, subgroups)
    else
        group = AccountGroup{A}(id, number, name, isdebit, accounts, subgroups)
        add_subgroup!(parent.subgroups, group)
        return acc
    end
end

function AccountGroup(accounts::AbstractVector{A}; kwargs...) where {A<:AbstractAccount}
    ag = AccountGroup(A; kwargs...)
    add_account!.(Ref(ag), accounts)
    return ag
end


macro ifsomething(ex)
    quote
        result = $(esc(ex))
        result === nothing && return nothing
        result
    end
end

function Base.iterate(group::AccountGroup, 
        (accounts_state, subgroups_state)=(0, 1))
    """allows `for account in group`"""
    acccounts_iter_attempt = iterate(values(group.accounts), accounts_state)
    account, accounts_state = if !isnothing(acccounts_iter_attempt)
        accounts_iter_attempt
    else
        account, subgroups_state = @ifsomething iterate(values(group.subgroups),
                                                        subgroups_state)
        return (account, (accounts_state, subgroups_state))
        # optimize here: return accounts_state as nothing then dipatch
    end
    return (account, (accounts_state, subgroups_state))
end

function add_account!(grp::AccountGroup{A}, acc::A) where {A <: AbstractAccount}
    if id(acc) ∈ keys(grp.accounts) # FIXME check subgroups?
        warn("Account already in ledger.")
        return
    end
    grp.accounts[id(acc)] = acc
end

function add_account!(grp::AccountGroup{A}, group::AccountGroup{A}) where {A <: AbstractAccount}
    push!(grp.subgroups, group)
end


function balance(group::AccountGroup{<:AbstractAccount{P}}) where {P <: Position}
    isnothing(iterate(group)) && return P(0)
    return sum(account for account in group)
end
