const { CostExplorer }  = require('aws-sdk');
const { IncomingWebhook } = require('@slack/webhook');

const config = {
    SLACK_WEBHOOK_URL: process.env.SLACK_WEBHOOK_URL || '',
    SLACK_CHANNEL: process.env.SLACK_CHANNEL || '#testing',
    SLACK_USERNAME: process.env.SLACK_USERNAME || 'AWS Billing daily notification',
};

const costExplorer = new CostExplorer();
const webhook = new IncomingWebhook(config.SLACK_WEBHOOK_URL);

/**
 * @param {Date} d
 * @return {string}
 */
function dateFormat(d) {
    return d.getFullYear()
        + '-' +
        ('0' + (d.getMonth() + 1)).slice(-2)
        + '-' +
        ('0' + d.getDate()).slice(-2)
}

/**
 * @param {number} v
 * @return {string}
 */
function round(v) {
    const e = 10000000;
    return (Math.round(v * e)  / e).toString();
}

exports.handler = async function () {
    const end = new Date();
    const start = new Date(end.getFullYear(), end.getMonth(), end.getDate() - 1);

    //console.log('TimePeriod:', `${dateFormat(start)} ... ${dateFormat(end)}`);

    const results = await costExplorer.getCostAndUsage({
        TimePeriod: {
            Start: dateFormat(start),
            End: dateFormat(end),
        },
        Granularity: 'DAILY',
        Metrics: ['UnblendedCost'],
        GroupBy: [{
            Type: 'DIMENSION',
            Key : 'SERVICE'
        }]
    }).promise();

    //console.log('CostAndUsage:', JSON.stringify(results, null, 2));

    let total = 0.0;
    const details = [];

    for (const result of results.ResultsByTime || []) {
        for (const group of result.Groups || []) {
            if (group.Keys && group.Metrics && group.Metrics.UnblendedCost && group.Metrics.UnblendedCost.Amount) {
                const amount = parseFloat(group.Metrics.UnblendedCost.Amount);
                if (amount > 0) {
                    details.push({
                        title: group.Keys[0],
                        value: `${round(amount)} USD`,
                        short: true,
                    });
                }
                total += amount;
            }
        }
    }

    if (details.length) {
        await webhook.send({
            username: config.SLACK_USERNAME,
            icon_emoji: ':moneybag:',
            channel: config.SLACK_CHANNEL,
            attachments: [
                {
                    color: 'warning',
                    pretext: '*SUMALLY*',
                    fields: [
                        {
                            title: 'Date',
                            value: dateFormat(start),
                        },
                        {
                            title: 'Total',
                            value: `${round(total)} USD`,
                        },
                    ],
                },
                {
                    color: 'warning',
                    pretext: '*DETAILS*',
                    fields: details,
                },
            ],
        });
    }
}
