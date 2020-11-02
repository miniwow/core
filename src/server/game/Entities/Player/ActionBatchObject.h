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

#ifndef ActionBatchObject_h__
#define ActionBatchObject_h__

#include "Define.h"
#include "Spell.h"
#include "WorldPacket.h"

class TC_GAME_API ActionBatchObject
{
    public:
        ActionBatchObject(Player* owner);

        void CreateBatchObject(WorldPacket& data);
        void ProcessBatchedObjects();

        bool IsPacketBatchable(WorldPacket& data) const;

    private:
        // Packet storage which contains all stored up packets
        std::queue<WorldPacket> m_packetBatch;

        // Player owner who is going to process all batched up packets
        Player* m_owner;
};

#endif // ActionBatchObject_h__
