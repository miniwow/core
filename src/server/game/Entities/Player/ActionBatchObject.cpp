/*
* Copyright (C) 2008-2018 TrinityCore <https://www.trinitycore.org/>
*
* This program is free software; you can redistribute it and/or modify it
* under the terms of the GNU General Public License as published by the
* Free Software Foundation; either version 2 of the License, or (at your
* option) any later version.
*
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
* FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
* more details.
*
* You should have received a copy of the GNU General Public License along
* with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#include "ActionBatchObject.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "WorldSession.h"

ActionBatchObject::ActionBatchObject(Player* owner) : m_owner(owner)
{
}

void ActionBatchObject::CreateBatchObject(WorldPacket& data)
{
    if (IsPacketBatchable(data))
        m_packetBatch.push(data);
}

void ActionBatchObject::ProcessBatchedObjects()
{
    while (!m_packetBatch.empty())
    {
        WorldPacket data = m_packetBatch.front();
        WorldSession* session = m_owner->GetSession();
        session->HandleCastSpellOpcode(data);
        m_packetBatch.pop();
    }
}

bool ActionBatchObject::IsPacketBatchable(WorldPacket& data) const
{
    if (data.GetOpcode() != CMSG_CAST_SPELL) return false;
    // vehicle casts and mind controls are also getting batched
    // if (m_owner->m_unitMovedByMe != m_owner) return true;

    // only reading the spell targets for now
    data.read_skip<uint8>();  // cast count
    data.read_skip<uint32>(); // spell Id
    data.read_skip<uint32>(); // glyph index
    data.read_skip<uint8>();  // cast flags
    SpellCastTargets targets;
    targets.Read(data, m_owner);
    data.rfinish();

    // if we target ourself the cast will be instant. Otherwise it will be batched
    if (targets.GetUnitTarget() && targets.GetUnitTarget() == m_owner)
    {
        if (WorldSession* session = m_owner->GetSession())
            session->HandleCastSpellOpcode(data);

        return false;
    }

    return true;
}
