export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { userToken, role = 'member' } = req.body;

  try {
    const response = await fetch(
      'https://nluvnjydydotsrpluhey.supabase.co/functions/v1/create-invite',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${userToken}`,
          'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5sdXZuanlkeWRvdHNycGx1aGV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjE5MjAsImV4cCI6MjA3NjMzNzkyMH0.p5S8vYtZeYqp24avigifhjEDRaKv8TxJTaTkeLoE5mY'
        },
        body: JSON.stringify({ userToken, role })
      }
    );

    const data = await response.json();
    return res.status(response.status).json(data);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
}
