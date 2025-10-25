// API placeholder illustrating integration points for Bride Buddy UI

export async function fetchDashboardData() {
  // Placeholder data to illustrate layout
  return Promise.resolve({
    daysUntilWedding: 142,
    teamMembers: [
      { name: 'Amelia', role: 'Owner' },
      { name: 'Noah', role: 'Partner' },
      { name: 'Priya', role: 'Co-planner' },
      { name: 'Zara', role: 'Bestie' }
    ],
    tasksCompleted: 18,
    totalTasks: 32,
    activities: [
      { actor: 'Priya', action: 'added vendor', target: 'Floral Atelier', time: '2h ago' },
      { actor: 'Zara', action: 'updated guest list', target: '', time: '4h ago' },
      { actor: 'Noah', action: 'approved budget', target: 'Venue décor', time: 'Yesterday' }
    ]
  });
}

export async function fetchChatHistory() {
  return Promise.resolve([
    {
      id: '1',
      title: 'Design vision with AI',
      preview: 'AI: I recommend combining Art Nouveau florals with ambient lighting...',
      time: 'Today • 2:40 PM'
    },
    {
      id: '2',
      title: 'Vendor shortlist',
      preview: 'You: Please shortlist photographers in Napa Valley',
      time: 'Yesterday • 7:10 PM'
    }
  ]);
}
