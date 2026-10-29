// CindrixCraft: LAN discovery
// SPDX-License-Identifier: LGPL-2.1-or-later
//
// A hosting world announces itself with a small UDP broadcast packet every
// couple of seconds. The main menu listens for those packets and shows the
// worlds in the Multiplayer list, so nobody has to type an IP address.
//
// Packet format (text, UTF-8, at most 512 bytes):
//   CXC1\n
//   name=<world name>\n
//   port=<game port>\n
//   game=<game id>\n
//   players=<number>\n
//   max=<number>\n
//   version=<engine version>\n

#pragma once

#include "irrlichttypes.h"
#include "network/socket.h"
#include <map>
#include <memory>
#include <string>
#include <vector>

namespace lan
{

// UDP port used for discovery packets (not the game port)
constexpr u16 DISCOVERY_PORT = 30001;

struct Info
{
	std::string name;
	u16 port = 30000;
	std::string game;
	u32 players = 0;
	u32 max_players = 0;
	std::string version;
};

struct Entry
{
	std::string address;
	Info info;
	u64 last_seen_ms = 0;
};

// Used by the server: sends an announcement every `interval` seconds.
class Announcer
{
public:
	// Returns true when it is time to send the next announcement.
	bool due(float dtime);
	void send(const Info &info);

private:
	UDPSocket m_socket;
	bool m_socket_ready = false;
	bool m_socket_failed = false;
	float m_timer = 1000.0f; // announce right away
};

// Used by the main menu: collects announcements from the network.
class Listener
{
public:
	// Starts listening if not already started. Safe to call repeatedly.
	void start();
	void stop();
	bool started() const { return m_started; }

	// Reads pending packets and drops stale entries.
	// Returns true if the visible list changed.
	bool poll();

	std::vector<Entry> getServers() const;

private:
	std::unique_ptr<UDPSocket> m_socket;
	bool m_started = false;
	bool m_start_failed = false;
	std::map<std::string, Entry> m_entries; // key: "address:port"
};

Listener &listener();

// Exposed for tests
std::string serializePacket(const Info &info);
bool parsePacket(const char *data, int size, Info &info);

}
